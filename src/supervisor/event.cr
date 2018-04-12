module Supervisor
  enum Event
    START
    STOP
    STARTED
    EXITED
    RETRY
    FATAL
    END
  end
end
