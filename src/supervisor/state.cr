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

    def running?
      self == RUNNING
    end
  end
end


