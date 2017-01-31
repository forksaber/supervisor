module Supervisor
  class Process

    enum State
      STOPPED
      FATAL
      EXITED
      STARTING
      BACKOFF
      RUNNING
      STOPPING
    end

    enum Event
      START
      STOP
      STARTED
      EXITED
      RETRY
      FATAL
    end
 
    getter state = State::STOPPED
    getter job : Job

    @try_count = 0
    @chan = Channel(Event).new
    @process : (::Process | Nil)

    def initialize(@job)
      listen
    end

    def stop_async
      send_event Event::STOP
    end

    def run
      send_event Event::START
    end

    private def listen
      spawn do
        loop do
          event = @chan.receive
          state_machine event
          puts "new state: #{@state}"
        end
      end
    end

    private def state_machine(event : Event)
      case {@state, event}

      when {State::STOPPED, Event::START}
        @state = State::STARTING
        start
      when {State::FATAL, Event::START}
        @state = State::STARTING
        start
      when {State::EXITED, Event::START}
        @state = State::STARTING
        start

      when {State::STARTING, Event::STARTED}
        @state = State::RUNNING
      when {State::STARTING, Event::EXITED}
        @state = State::BACKOFF
        @try_count += 1
        if @try_count >= @job.startretries
          send_event Event::FATAL
        else
          send_event Event::RETRY
        end

      when {State::BACKOFF, Event::RETRY}
        @state = State::STARTING
        start
      when {State::BACKOFF, Event::FATAL}
        @state = State::FATAL

      when {State::RUNNING, Event::STOP}
        @state = State::STOPPING
        stop
      when {State::RUNNING, Event::EXITED}
        @state = State::EXITED
        send_event Event::START if @job.autorestart

      when {State::STOPPING, Event::EXITED}
        @state = State::STOPPED
        @try_count = 0
      else
        puts "unknown state/event combo: #{@state}, #{event}"
      end
    end

    private def send_event(event : Event)
      spawn { @chan.send event }
    end

    private def start
      spawn do
        exited = false
        wait_chan = Channel(Nil).new
        begin
          stdout = File.open(@job.stdout_logfile, "a+")
          stderr = @job.stderr_logfile ? File.open(@job.stderr_logfile.as(String), "a+") : stdout
          stdout.flush_on_newline = true
          stderr.flush_on_newline = true

          ::Process.run(**spawn_opts) do |process|
            spawn { sleep @job.startsecs; send_event Event::STARTED unless exited}
            @process = process
            puts process.inspect
            spawn do 
              process.error.each_line { |l| stderr.not_nil!.puts l }
              wait_chan.send nil
            end
            process.output.each_line { |l| stdout.puts l }
          end

          wait_chan.receive
        rescue e
          puts e
        ensure
          exited = true
          send_event Event::EXITED
          stdout.close if stdout
          stderr.try &.close if stderr
        end
      end
    end

    private def stop
      spawn do
        process = @process
        process.kill if process
        sleep @job.stopwaitsecs
        if (process && !process.terminated?)
          process.kill(Signal::KILL)
          puts "Killed #{process.pid}"
        end
      end
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
