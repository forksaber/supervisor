DONE
- [x] process: .destroy
- [x] state_machine: fix listen fiber leak
- [x] add uptime
- [x] refactor rpc call2

ORDER:
- [x] remove unneeded processes first
- [ ] server: implement shutdown(parallel stop with channel synchro)
- [ ] job: support env ..with %(process_num)
- [ ] env overrides


PENDING
- [ ] add linear/exponential backoff
- [ ] take abstract socket lock when running rr

MAYBE
- [ ] read config from tmp/sv.yml, jobs.yml when running in daemon mode
- [ ] state_machine: refactor to use state transitions
- [ ] add logger
- [ ] add sv.yml or process_manager
- [ ] stop_proc: run in spawn

- [ ] show/log spawn errors (maybe)
- [ ] autorestart: true(done), false(done), unexpected(not implemented)
- [ ] can use mutex to ensure started/exited ordering
- [ ] size based logrotate(needs shared fds for similar processes to account for log size)

ISSUES
- [x] race condition in STARTED/EXITED will cause infinite start retries (in a very unlikely case where startsecs ~= num secs for which process runs before exiting)
    due to the following state transitions
    STARTING -> EXITED -> STARTING -> RUNNING(event started) -> EXITED -> RUNNING
- [x] Process.kill can kill the wrong process (race condition in kill/wait)
