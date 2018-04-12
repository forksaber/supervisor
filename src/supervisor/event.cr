module Supervisor
  enum Event
    START
    STOP
    STARTED
    EXITED
    RETRY
    FATAL
    SHUTDOWN
  end
end
