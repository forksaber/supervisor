module Supervisor
  alias ProcessTuple = NamedTuple(
    name: String,
    group_id: String,
    command: String,
    working_dir: String,

    stdout_logfile: String,
    stderr_logfile: String,

    env: Hash(String, String),
    autorestart: Bool,

    stopsignal: Signal,
    stopasgroup: Bool,
    killasgroup: Bool,

    startsecs: Int32,
    startretries: Int32,
    stopwaitsecs: Int32
  )
end
