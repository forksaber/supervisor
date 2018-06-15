DONE
- [x] process: .destroy
- [x] state_machine: fix listen fiber leak
- [x] add uptime
- [x] refactor rpc call2
- [x] use mutex to ensure started/exited ordering
- [x] remove unneeded processes first
- [x] job: support env ..with %<process_num>02d
- [x] config overrides
- [x] reload(dir)....(sv rr) will reread config from current dir
- [x] server: implement shutdown(parallel stop with channel synchro)
- [x] make command strings with arguments work
- [x] refactor state_machine to process_fsm
- [x] application logs are not routed through sv
- [x] add stop/start commands
- [x] fail process.start on first spawn error and change process state to FATAL
- [x] add linear backoff (when a RUNNING process exits...it will restarted 'startretries' times with linear backoff)

PENDING
- [ ] take abstract socket lock when running rr/start/stop commands
- [ ] implement forced-shutdown
- [ ] port to crystal 0.25.0

figure out how nginx/apache does log writes with 32k buffer....with or without locks?

MAYBE
- [ ] implement fd/socket passing
- [ ] state_machine: refactor to use state transitions
- [ ] add logger
- [ ] show/log spawn errors
- [ ] autorestart: true(done), false(done), unexpected(not implemented)

UNLIKELY
- [ ] size based logrotate(needs shared fds for similar processes to account for log size)

DESIGN ISSUES
- [x] race condition in STARTED/EXITED will cause infinite start retries (in a very unlikely case where startsecs ~= num secs for which process runs before exiting)
    due to the following state transitions
    STARTING -> EXITED -> STARTING -> RUNNING(event started) -> EXITED -> RUNNING
- [x] Process.kill can kill the wrong process (race condition in kill/wait)
