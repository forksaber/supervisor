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
        end
      end
    end

    private def process_event(event : Event)
      prev_state = @state
      case {state, event}

      when {State::STOPPED, Event::START}
        @state = State::STARTING
        start_process

      when {State::FATAL, Event::START}
        @state = State::STARTING
        start_process

      when {State::EXITED, Event::START}
        @state = State::STARTING
        start_process

      when {State::STARTING, Event::STARTED}
        @state = State::RUNNING
        @try_count = 0

      when {State::STARTING, Event::EXITED}
        @state = State::BACKOFF
        @try_count += 1
        if @try_count >= @popts[:startretries]
          @state = State::FATAL
        else
          @state = State::STARTING
          start_process
        end

      when {State::STARTING, Event::STOP}
        @state = State::STOPPING
        process = @process
        stop_process(process, @popts[:stopwaitsecs]) if process

      when {State::RUNNING, Event::STOP}
        @state = State::STOPPING
        process = @process
        stop_process(process, @popts[:stopwaitsecs]) if process

      when {State::RUNNING, Event::EXITED}
        @state = State::EXITED
        if @popts[:autorestart]
          @state = State::STARTING
          start_process
        end

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
      if changed
        logger.info "(#{group_id}) (#{name}) #{curr_state}"
      end
    end

    private def start_process
      mutex = Mutex.new
      spawn run_process(mutex)
    end

    private def run_process(mutex)
      exited = false
      process = ::Process.new(**spawn_opts)
      @process = process
      spawn do
        sleep @popts[:startsecs]
        mutex.synchronize { fire Event::STARTED if ! exited }
      end
      logger.info "(#{group_id}) (#{name}) Pid: ##{process.pid}"
      @started_at = Time.now.epoch
      process.wait
    rescue e
      puts "exception : #{e}"
      process = @process
      stop_process(process, 1) if process
    ensure
      @process = nil
      mutex.synchronize do
        exited = true
        fire Event::EXITED
      end
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
