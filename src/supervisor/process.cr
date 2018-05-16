require "./process_fsm"
require "./ext/process"
require "./logger"
require "atomic"

module Supervisor
  alias ProcessData = NamedTuple(name: String, group_id: String, state: State, pid: Int32, started_at: Int64)

  class Process

    include Logger

    @fsm : ProcessFSM
    delegate state, name, group_id, pid, started_at, to: @fsm

    enum Shutdown
      NOT_STARTED
      IN_PROGRESS
      COMPLETED
    end

    def initialize(tuple : ProcessTuple)
      @fsm = ProcessFSM.new(tuple)
      @shutdown = Atomic(Shutdown).new(Shutdown::NOT_STARTED)
    end

    def to_h
      ProcessData.new(
        name: name,
        group_id: group_id,
        state: state,
        pid: pid,
        started_at: started_at
      )
    end

    def start
      unsubscribe_proc = ->(prev : State, current : State) do
        changed = (prev != current)
        already_started = current.started? && !changed
        if current.running? || current.stopped?
          true
        elsif already_started
          true
        else
          false
        end
      end

      chan = Channel({Bool, State, Bool}).new(1)
      callback = ->(prev : State, current : State) do
        logger.debug({prev, current})
        changed = (prev != current)
        already_started = current.started? && !changed

        if already_started
          chan.send({true, current, changed})
        elsif current.running?
          chan.send({true, current, changed})
        elsif current.stopped?
          chan.send({false, current, changed})
        end
        nil
      end
      @fsm.subscribe(callback, unsubscribe_proc)
      fire Event::START
      chan.receive
    end

    def stop
      state = self.state
      return {true, state, false} if state.stopped?
      unsubscribe_proc = ->(prev : State, current : State) do
        current.stopped? ? true : false
      end
      chan = Channel({Bool, State, Bool}).new(1)
      callback = ->(prev : State, current : State) do
        changed = (prev != current)
        if current.stopped?
          chan.send({true, current, changed})
        end
        nil
      end
      @fsm.subscribe(callback, unsubscribe_proc)
      fire Event::STOP
      chan.receive
    end

    def reopen_logs
      stdout = @stdout
      stderr = @stderr
      if stdout
        stdout.reopen(File.open(@job.stdout_logfile, "a+"))
      end
      if stderr
        stderr.reopen(File.open(@job.stderr_logfile, "a+"))
      end
    end

    def shutdown
      return true if @shutdown.get == Shutdown::COMPLETED
      return false if @shutdown.get == Shutdown::IN_PROGRESS
      _, ok = @shutdown.compare_and_set(Shutdown::NOT_STARTED, Shutdown::IN_PROGRESS)
      return false if ! ok
      stop
      fire Event::SHUTDOWN
      @shutdown.set(Shutdown::COMPLETED)
      true
    end

    private def fire(event)
      @fsm.fire(event)
    end
  end
end
