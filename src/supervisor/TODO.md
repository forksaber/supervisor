DONE
- [x] process: .destroy
- [x] state_machine: fix listen fiber leak
- [x] add uptime
- [x] refactor rpc call2
- [x] use mutex to ensure started/exited ordering
- [x] remove unneeded processes first
- [x] job: support env ..with %<process_num>02d
- [x] config overrides

ORDER:
- [ ] server: implement shutdown(parallel stop with channel synchro)
- [ ] add working directory


PENDING
- [ ] add linear/exponential backoff
- [ ] take abstract socket lock when running rr

MAYBE
- [ ] state_machine: refactor to use state transitions
- [ ] add logger
- [ ] add sv.yml or process_manager
- [ ] stop_proc: run in spawn

- [ ] show/log spawn errors
- [ ] autorestart: true(done), false(done), unexpected(not implemented)
- [ ] size based logrotate(needs shared fds for similar processes to account for log size)

DESIGN ISSUES
- [x] race condition in STARTED/EXITED will cause infinite start retries (in a very unlikely case where startsecs ~= num secs for which process runs before exiting)
    due to the following state transitions
    STARTING -> EXITED -> STARTING -> RUNNING(event started) -> EXITED -> RUNNING
- [x] Process.kill can kill the wrong process (race condition in kill/wait)
