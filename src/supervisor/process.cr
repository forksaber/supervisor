require "./state_machine"
require "./custom_process"

module Supervisor
  class Process

    getter job : Job
    @process : (::Process | Nil)
    @name : String
    @fsm : StateMachine
    @stdout : File?
    @stderr : File?

    delegate state, to: @fsm

    def initialize(@job, name = nil)
      @name = name || @job.name
      @fsm = StateMachine.new(
        retries: @job.startretries,
        start_proc: -> (callback : EventCallback?) { start_process(callback); nil },
        stop_proc: -> { process = @process; stop_process(process, @job.stopwaitsecs) if process; nil },
        autorestart: @job.autorestart
      )
    end

    def run 
      fire Event::START, nil
    end

    def start
      chan = Channel({Bool, State, Bool}).new
      callback = ->(prev : State, current : State) do
        puts({prev, current})
        changed = (prev != current)
        already_started = current.started? && !changed

        puts ">> #{@name}: #{prev} -> #{current}"
        if already_started
          puts "already running"
          chan.send({true, current, changed})
        elsif current == State::RUNNING
          chan.send({true, current, changed})
        elsif current.stopped?
          chan.send({false, current, changed})
        end
        nil
      end
      fire Event::START, callback
      chan.receive
    end

    def stop
      chan = Channel({Bool, State, Bool}).new(1)
      callback = ->(prev : State, current : State) do
        changed = (prev != current)

        puts "#{@name} -> #{current}"
        if current.stopped?
          chan.send({true, current, changed})
        end
        nil
      end
      fire Event::STOP, callback
      x = chan.receive
    end

    private def fire(*args, **kwargs)
      @fsm.fire(*args, **kwargs)
    end

    private def start_process(callback : EventCallback?)
      spawn_chan = Channel(Nil).new(1)
      exception_chan = Channel(Nil).new(1)
      spawn do
        exit_chan = Channel(Nil).new(1)
        start_chan = Channel(Nil).new(1)
        begin
          stdout = File.open(@job.stdout_logfile, "a+")
          stderr = @job.stderr_logfile ? File.open(@job.stderr_logfile.as(String), "a+") : File.open(@job.stdout_logfile, "a+")
          stdout.flush_on_newline = true
          stderr.flush_on_newline = true
          @stdout = stdout
          @stderr = stderr
          
          ::Process.run(**spawn_opts) do |process|
            @process = process
            spawn_chan.send nil
            spawn do
              sleep @job.startsecs
              select
              when exit_chan.receive
              else
                start_chan.send nil
                fire Event::STARTED, callback
              end
            end
            
            wait_chan = Channel(Nil).new(1)
            spawn do
              process.error.each_line { |l| stderr.not_nil!.puts l }
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
            fire Event::EXITED, nil
          else
            puts "Exited"
            fire Event::EXITED, callback, async: true
          end
        end
      end

      select
      when spawn_chan.receive
        puts "received"
      when exception_chan.receive
        puts "ex-received"
      end
    end

    private def stop_process(process : ::Process, stop_wait)
      process.kill
      sleep 0.05
      return if process.terminated?
      sleep stop_wait
      if process.exists?
        group_pid = 0 - process.pid
        puts group_pid
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
        error: pipe_error,
        env: @job.env
      }
    end

    private def pipe_error
      (@job.redirect_stderr || @job.stderr_logfile) ? nil : false
    end

  end
end
