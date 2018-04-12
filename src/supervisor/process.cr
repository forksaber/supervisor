require "./state_machine"
require "./custom_process"
require "./logger"

module Supervisor
  alias ProcessData = NamedTuple(name: String, group_id: String, state: String, pid: Int32)

  class Process

    include Logger

    getter job : Job
    getter name : String
    @process : (::Process | Nil)
    @fsm : StateMachine
    @stdout : File?
    @stderr : File?
    @group_id : String

    delegate state, to: @fsm

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
    end

    def to_h
      process = @process
      pid = process ? process.pid : 0
      ProcessData.new(name: @name, group_id: @group_id, state: state.to_s, pid: pid)
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

    private def fire(*args, **kwargs)
      @fsm.fire(*args, **kwargs)
    end

    private def start_process
      spawn_chan = Channel(Nil).new(1)
      exception_chan = Channel(Nil).new(1)
      spawn do
        exit_chan = Channel(Nil).new(1)
        start_chan = Channel(Nil).new(1)
        begin
          stdout = File.open(@job.stdout_logfile, "a+")
          stderr = File.open(@job.stderr_logfile, "a+")
          stdout.flush_on_newline = true
          stderr.flush_on_newline = true
          @stdout = stdout
          @stderr = stderr

          ::CustomProcess.run(**spawn_opts) do |process|
            @process = process
            spawn_chan.send nil
            spawn do
              sleep @job.startsecs
              select
              when exit_chan.receive
              else
                start_chan.send nil
                logger.info "(#{@group_id}) (#{@name}) Pid: ##{process.pid}"
                fire Event::STARTED
              end
            end

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
          exception_chan.send nil
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
          select
          when start_chan.receive
            fire Event::EXITED
          else
            logger.debug "Exited"
            fire Event::EXITED, async: true
          end
        end
      end

      select
      when spawn_chan.receive
      when exception_chan.receive
      end
    end

    private def stop_process(process : ::Process, stop_wait : Number)
      process.kill
      sleep 0.05
      return if process.terminated?
      sleep stop_wait
      if process.exists?
        group_pid = 0 - process.pid
        ::Process.kill(Signal::KILL, group_pid)
        puts "Killed #{process.pid}"
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
