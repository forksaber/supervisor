require "./state_machine"
require "./ext/process"
require "./logger"
require "atomic"

module Supervisor
  alias ProcessData = NamedTuple(name: String, group_id: String, state: State, pid: Int32, started_at: Int64)

  class Process

    include Logger

    getter name : String
    getter job : Job
    @process : ::Process?
    @fsm : StateMachine
    @stdout : File?
    @stderr : File?
    @group_id : String
    @started_at : Int64

    delegate state, to: @fsm

    enum Shutdown
      NOT_STARTED
      IN_PROGRESS
      COMPLETED
    end

    def initialize(@job, name)
      @name = name
      @group_id = @job.group_id
      @fsm = StateMachine.new(
        name: @name,
        group_id: @group_id,
        retries: @job.startretries,
        start_proc: -> { start_process; nil },
        stop_proc: -> { process = @process; stop_process(process, @job.stopwaitsecs) if process; nil },
        autorestart: @job.autorestart
      )
      @shutdown = Atomic(Shutdown).new(Shutdown::NOT_STARTED)
      @started_at = 0_i64
    end

    def to_h
      process = @process
      pid = process ? process.pid : 0
      ProcessData.new(
        name: @name,
        group_id: @group_id,
        state: state,
        pid: pid,
        started_at: @started_at
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

    private def start_process
      start_chan = Channel(Nil).new(1)
      exit_chan = Channel(Nil).new(1)

      spawn do
        select
        when start_chan.receive
          fire Event::STARTED
          exit_chan.receive
          fire Event::EXITED
        when exit_chan.receive
          fire Event::EXITED
        end
      end
      spawn run_process(start_chan, exit_chan)
    end

    private def run_process(start_chan, exit_chan)
      stdout = File.open(@job.stdout_logfile, "a+")
      stderr = File.open(@job.stderr_logfile, "a+")
      stdout.flush_on_newline = true
      stderr.flush_on_newline = true
      @stdout = stdout
      @stderr = stderr

      ::Process.run(**spawn_opts) do |process|
        @process = process

        spawn do
          sleep @job.startsecs
          start_chan.send nil
        end
        logger.info "(#{@group_id}) (#{@name}) Pid: ##{process.pid}"
        @started_at = Time.now.epoch

        wait_chan = Channel(Nil).new(1)
        spawn do
          process.error.each_line { |l| stderr.not_nil!.puts l }
        ensure
          wait_chan.send nil
        end
        process.output.each_line { |l| stdout.puts l }
        wait_chan.receive
      end

    rescue e
      puts "exception : #{e}"
      process = @process
      stop_process(process, 1) if process
    ensure
      @process.try &.wait
      @process = nil
      stdout.close if stdout
      stderr.try &.close if stderr
      @stdout = nil
      @stderr = nil
      exit_chan.send nil
    end

    private def stop_process(process : ::Process, stop_wait : Number)
      ret = process.kill
      return if !ret
      spawn do
        sleep stop_wait
        process.killgroup(Signal::KILL)
      end
    rescue e
      puts "#{e}, #{process.pid}"
    end

    private def spawn_opts
      {
        command: @job.command,
        chdir: @job.working_dir,
        output: ::Process::Redirect::Pipe,
        error: ::Process::Redirect::Pipe,
        env: @job.env
      }
    end

  end
end
