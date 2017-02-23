module Supervisor   
  
  enum State
    STOPPED
    FATAL
    EXITED
    STARTING
    BACKOFF
    RUNNING
    STOPPING
  end

  enum Event
    START
    STOP
    STARTED
    EXITED
    RETRY
    FATAL
  end
 
  class StateMachine

    TRANSITIONS = {
      State::STOPPED => {
        Event::START => State::STARTING
      },

      State::FATAL => {
        Event::START => State::STARTING
      },

      State::EXITED => {
        Event::START => State::STARTING
      },

      State::STARTING => {
        Event::STARTED => State::RUNNING,
        Event::EXITED => State::BACKOFF,
      },

      State::BACKOFF => {
        Event::RETRY => State::STARTING,
        Event::FATAL => State::FATAL
      },

      State::RUNNING => {
        Event::EXITED => State::EXITED,
        Event::STOP => State::STOPPING,
      },

      State::STOPPING => {
        Event::EXITED => State::STOPPED
      }
    }


    TRANSITIONS = {
      Event::START => {
        State::STOPPED => State::STARTING,
        State::EXITED => State::STARTING,
        State::FATAL => State::STARTING
      },

      Event::STOP => {
        State::RUNNING => State::STOPPING
      }



    }  

    getter state = State::STOPPED
    getter start_proc : Proc(Void)
    getter stop_proc : Proc(Void)

    @try_count = 0
    @chan = Channel(Event).new
    @retries : Int32
    @autorestart : Bool

    def initialize(@retries, @start_proc, @stop_proc, @autorestart)
      listen
    end

    def fire(event : Event)
      spawn { @chan.send event }
    end

    private def listen
      spawn do
        loop do
          event = @chan.receive
          process_event event
          puts "new state: #{@state}"
        end
      end
    end

    private def process_event(event : Event)
      case {@state, event}

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
        fire Event::START if autorestart

      when {State::STOPPING, Event::EXITED}
        @state = State::STOPPED
      else
        puts "unknown state/event combo: #{@state}, #{event}"
      end
    end
  end
end
