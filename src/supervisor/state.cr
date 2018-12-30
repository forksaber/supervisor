module Supervisor
  enum State
    STOPPED
    FATAL
    EXITED
    STARTING
    RETRYING
    BACKOFF
    RUNNING
    STOPPING
    SHUTTING_DOWN
    SHUTDOWN

    def stopped?
      [STOPPED, FATAL, SHUTDOWN].includes? self
    end

    def started?
      [STARTING, BACKOFF, RUNNING, RETRYING].includes? self
    end

    def running?
      self == RUNNING
    end
  end
end


