module Supervisor
  enum Event
    START
    STOP
    RETRY
    STARTED
    EXITED
    SHUTDOWN
  end
end
