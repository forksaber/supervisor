require "./logger"
require "./state"
require "./event"
module Supervisor

  alias EventCallback = Proc(State, State, Nil)
  alias UnsubscribeProc =  Proc(State, State, Bool)

  class ProcessFSM

    include Logger

    @popts : ProcessTuple
    getter state = State::STOPPED
    getter started_at : Int64 = 0_i64

    @try_count = 0
    @chan = Channel(Event).new
    @mutex : Mutex
    @process : ::Process?

    def initialize(popts)
      @popts = popts
      @mutex = Mutex.new
      @subscriptions = Hash(EventCallback, UnsubscribeProc).new
      listen
    end

    def name
      @popts[:name]
    end

    def group_id
      @popts[:group_id]
    end

    def pid
      process = @process
      process ? process.pid : 0
    end

    def fire(event : Event)
      @chan.send(event)
    end

    def subscribe(callback : EventCallback, unsubscribe_proc : UnsubscribeProc)
      @mutex.synchronize { @subscriptions[callback] = unsubscribe_proc }
    end

    private def listen
      spawn do
        loop do
          event = @chan.receive
          break if event == Event::SHUTDOWN && @state.stopped?
          process_event event
          next if @state != State::BACKOFF
          handle_backoff
        end
      end
    end

    private def handle_backoff
      t = {@try_count, 60}.min
      backoff_chan = Channel(Nil).new(1)
      spawn { sleep t; backoff_chan.send  nil }
      event = loop do
        select
        when backoff_chan.receive
          break Event::RETRY
        when e = @chan.receive
          break e if {Event::START, Event::STOP}.includes? e
          puts "unexpected event #{e} received in backoff state"
        end
      end
      process_event event
    end

    private def process_event(event : Event)
      prev_state = @state
      case {state, event}

      when {State::STOPPED, Event::START},
           {State::FATAL, Event::START},
           {State::EXITED, Event::START},
           {State::BACKOFF, Event::START}
        @state = State::STARTING
        start_process

      when {State::STARTING, Event::STOP},
           {State::RUNNING, Event::STOP},
           {State::RETRYING, Event::STOP}
        @state = State::STOPPING
        stop_process
      when {State::BACKOFF, Event::STOP}
        @state = State::STOPPED

      when {State::STARTING, Event::STARTED},
           {State::RETRYING, Event::STARTED}
        @state = State::RUNNING

      when {State::STARTING, Event::EXITED}
        @state = State::FATAL

      when {State::RUNNING, Event::EXITED}
        @state = State::EXITED
        @try_count = 0
        if @popts[:autorestart]
          @state = State::RETRYING
          start_process
        end

      when {State::RETRYING, Event::EXITED}
        @state = State::BACKOFF
        if @try_count >= @popts[:startretries]
          @state = State::FATAL
        end

      when {State::BACKOFF, Event::RETRY}
        @state = State::RETRYING
        @try_count += 1
        start_process

      when {State::STOPPING, Event::EXITED}
        @state = State::STOPPED
      else
        puts "unknown state/event combo: #{@state}, #{event}"
      end

      publish(prev_state, @state)
    end

    private def publish(prev_state : State, curr_state : State)
      log(prev_state, curr_state)
      @mutex.synchronize do
        @subscriptions.each do |event_callback, unsubscribe_proc|
          event_callback.call(prev_state, curr_state)
          @subscriptions.delete(event_callback) if unsubscribe_proc.call(prev_state, curr_state)
        end
      end
    end

    private def log(prev_state : State, curr_state : State)
      changed = (prev_state != curr_state)
      if curr_state == State::BACKOFF
        state_info = "#{curr_state} for #{{@try_count, 60}.min} secs"
      else
        state_info = curr_state
      end
      if changed
        logger.info "(#{group_id}) (#{name}) #{state_info}"
      end
    end

    private def start_process
      process = ::Process.new(**spawn_opts)
      @process = process
      @started_at = Time.now.epoch
      logger.info "(#{group_id}) (#{name}) Pid: ##{process.pid}"
      mutex = Mutex.new
      spawn wait_process(process, mutex)
    rescue e
      puts "exception : #{e}"
      stop_process(process, 1) if process
      spawn { fire Event::EXITED }
    end

    private def wait_process(process, mutex)
      exited = false
      spawn do
        sleep @popts[:startsecs]
        mutex.synchronize { fire Event::STARTED if ! exited }
      end
      process.wait
      @process = nil
      mutex.synchronize do
        exited = true
        fire Event::EXITED
      end
    end

    private def stop_process
      process = @process
      stop_process(process, @popts[:stopwaitsecs]) if process
    end

    private def stop_process(process : ::Process, stop_wait : Number)
      ret = process.kill
      return if !ret
      spawn do
        sleep stop_wait
        process.killgroup(Signal::KILL)
      end
    rescue e
      puts "#{e}, #{process.pid}"
    end

    private def spawn_opts
      {
        command: @popts[:command],
        args: @popts[:command_args],
        chdir: @popts[:working_dir],
        output: @popts[:stdout_logfile],
        error: @popts[:stderr_logfile],
        env: @popts[:env]
      }
    end
  end
end
