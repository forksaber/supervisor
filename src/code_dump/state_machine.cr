module Supervisor
  class Process

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
      STARTED
      EXITED
      RETRY
      FATAL
      STOP
    end
 
    STATE_MACHINE = {
      State::STOPPED => {
        :start => State::STARTING
      },

      State::FATAL => {
        :start => State::STARTING
      },

      State::EXITED => {
        :start => State::STARTING
      },

      State::STARTING => {
        :started => State::RUNNING,
        :exited => State::BACKOFF,
      },

      State::BACKOFF => {
        :retry => State::STARTING,
        :fatal => State::FATAL
      },

      State::RUNNING => {
        :exited => State::EXITED,
        :stop => State::STOPPING,
      },

      State::STOPPING => {
        :exited => State::STOPPED
      }
    }

    getter state = State::STOPPED

  end
end
