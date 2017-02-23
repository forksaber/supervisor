module Supervisor   
  
  enum State
    STOPPED
    FATAL
    EXITED
    STARTING
    BACKOFF
    RUNNING
    STOPPING

    def stopped?
      [STOPPED, FATAL].includes? self
    end

    def started?
      [STARTING, BACKOFF, RUNNING].includes? self
    end
  end

  enum Event
    START
    STOP
    STARTED
    EXITED
    RETRY
    FATAL
  end
 
  alias EventCallback = Proc(State, State, Nil)

  class StateMachine

    getter state = State::STOPPED
    getter start_proc : Proc(EventCallback?, Void)
    getter stop_proc : Proc(Void)

    @try_count = 0
    @chan = Channel({Event, EventCallback?}).new
    @retries : Int32
    @autorestart : Bool
    @stop_callback : EventCallback?

    def initialize(@retries, @start_proc, @stop_proc, @autorestart)
      listen
    end

    def fire(event : Supervisor::Event, callback : EventCallback? = nil, async = false)
      if async
        @chan.send({event, callback}) 
      else
        spawn { @chan.send({event, callback}) }
      end
    end

    private def listen
      spawn do
        loop do
          tuple = @chan.receive
          process_event tuple[0], tuple[1]
        end
      end
    end

    private def process_event(event : Event, callback)
      puts "received #{@state} : #{event}"
      state = @state
      case {state, event}

      when {State::STOPPED, Event::START}
        @state = State::STARTING
        @start_proc.call callback

      when {State::FATAL, Event::START}
        @state = State::STARTING
        @start_proc.call callback

      when {State::EXITED, Event::START}
        @state = State::STARTING
        @start_proc.call callback

      when {State::STARTING, Event::STARTED}
        @state = State::RUNNING
        @try_count = 0

      when {State::STARTING, Event::EXITED}
        @state = State::BACKOFF
        @try_count += 1
        if @try_count >= @retries
          fire Event::FATAL, callback
        else
          fire Event::RETRY, callback
        end

      when {State::STARTING, Event::STOP}
        @state = State::STOPPING
        @stop_callback = callback
        @stop_proc.call

      when {State::BACKOFF, Event::RETRY}
        @state = State::STARTING
        @start_proc.call callback

      when {State::BACKOFF, Event::FATAL}
        @state = State::FATAL

      when {State::RUNNING, Event::STOP}
        @state = State::STOPPING
        @stop_callback = callback
        @stop_proc.call

      when {State::RUNNING, Event::EXITED}
        @state = State::EXITED
        fire Event::START if @autorestart

      when {State::STOPPING, Event::EXITED}
        @state = State::STOPPED
        stop_callback = @stop_callback
        if stop_callback
          stop_callback.call(state, @state)
        end
      else
        puts "unknown state/event combo: #{@state}, #{event}"
      end

      if callback
        callback.call(state, @state)
      end

    end
  end
end
