require "./logger"
require "./state"
require "./event"
module Supervisor

  alias EventCallback = Proc(State, State, Nil)
  alias UnsubscribeProc =  Proc(State, State, Bool)

  class StateMachine

    include Logger

    getter state = State::STOPPED
    getter start_proc : Proc(Void)
    getter stop_proc : Proc(Void)

    @name : String
    @group_id : String
    @try_count = 0
    @chan = Channel(Event).new
    @retries : Int32
    @autorestart : Bool
    @mutex : Mutex

    def initialize(@name, @group_id, @retries, @start_proc, @stop_proc, @autorestart)
      @mutex = Mutex.new
      @subscriptions = Hash(EventCallback, UnsubscribeProc).new
      listen
    end

    def fire(event : Supervisor::Event, async = false)
      if async
        @chan.send(event)
      else
        spawn { @chan.send(event) }
      end
    end

    def subscribe(callback : EventCallback, unsubscribe_proc : UnsubscribeProc)
      @mutex.synchronize { @subscriptions[callback] = unsubscribe_proc }
    end

    private def listen
      spawn do
        loop do
          event = @chan.receive
          break if event == Event::END && @state.stopped?
          process_event event
        end
      end
    end

    private def process_event(event : Event)
      prev_state = @state
      case {state, event}

      when {State::STOPPED, Event::START}
        @state = State::STARTING
        @start_proc.call

      when {State::FATAL, Event::START}
        @state = State::STARTING
        @start_proc.call

      when {State::EXITED, Event::START}
        @state = State::STARTING
        @start_proc.call

      when {State::STARTING, Event::STARTED}
        @state = State::RUNNING
        @try_count = 0

      when {State::STARTING, Event::EXITED}
        @state = State::BACKOFF
        @try_count += 1
        if @try_count >= @retries
          fire Event::FATAL
        else
          fire Event::RETRY
        end

      when {State::STARTING, Event::STOP}
        @state = State::STOPPING
        @stop_proc.call

      when {State::BACKOFF, Event::RETRY}
        @state = State::STARTING
        @start_proc.call

      when {State::BACKOFF, Event::FATAL}
        @state = State::FATAL

      when {State::RUNNING, Event::STOP}
        @state = State::STOPPING
        @stop_proc.call

      when {State::RUNNING, Event::EXITED}
        @state = State::EXITED
        fire Event::START if @autorestart

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
        logger.info "(#{@group_id}) (#{@name}) #{curr_state}"
      end
    end

  end
end
