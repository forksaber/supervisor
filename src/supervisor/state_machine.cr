require "./logger"
require "./state"
require "./event"
module Supervisor

  alias EventCallback = Proc(State, State, Nil)
  alias UnsubscribeProc =  Proc(State, State, Bool)

  class StateMachine

    include Logger

    getter state = State::STOPPED
    getter start_proc : Proc(Channel(Nil), Channel(Nil), Void)
    getter stop_proc : Proc(Void)

    @name : String
    @group_id : String
    @try_count = 0
    @chan = Channel(Event).new
    @retries : Int32
    @autorestart : Bool
    @mutex : Mutex

    STOPPED_STATES = [State::STOPPED, State::FATAL, State::EXITED]

    def initialize(@name, @group_id, @retries, @start_proc, @stop_proc, @autorestart)
      @mutex = Mutex.new
      @subscriptions = Hash(EventCallback, UnsubscribeProc).new
      listen
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
      if STOPPED_STATES.includes? @state
        start
      else
        puts "unknown state/event combo: #{@state}, #{event}"
      end
    end

    private def start
      set_state State::STARTING
      start_chan = Channel(Nil).new(1)
      exit_chan = Channel(Nil).new(1)
      spawn { @start_proc.call(start_chan, exit_chan) }
      loop do
        select
        when start_chan.receive
          @try_count = 0
          set_state State::RUNNING
          break
        when exit_chan.receive
          set_state State::EXITED
          return retry_start
        when event = @chan.receive
          next if event != Event::STOP
          stop exit_chan
          return
        end
      end

      loop do
        select
        when exit_chan.receive
          set_state State::EXITED
          return start
        when event = @chan.receive
          next if event != Event::STOP
          stop exit_chan
          return
        end
      end
    end

    private def retry_start
      set_state State::BACKOFF
      @try_count += 1
      if @try_count >= @retries
        set_state State::FATAL
      else
        start
      end
    end

    private def stop(exit_chan)
      state = @state
      return if ! [State::STARTING, State::RUNNING].includes? state
      set_state State::STOPPING
      @stop_proc.call
      exit_chan.receive
      set_state State::STOPPED
    end

    private def set_state(state)
      prev_state = @state
      @state = state
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
        logger.info "(#{@group_id}) (#{@name}) #{curr_state}"
      end
    end

  end
end
