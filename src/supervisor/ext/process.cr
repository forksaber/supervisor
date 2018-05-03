lib LibC
  fun setpgrp()
end

require "./signal_child_handler"

class Process

  @mutex = Mutex.new
  @waited = false

  def initialize(command : String, args = nil, env : Env = nil, clear_env : Bool = false, shell : Bool = false,
                 input : Stdio = Redirect::Close, output : Stdio = Redirect::Close, error : Stdio = Redirect::Close, chdir : String? = nil)
    command, argv = Process.prepare_argv(command, args, shell)

    @wait_count = 0

    if needs_pipe?(input)
      fork_input, process_input = IO.pipe(read_blocking: true)
      if input.is_a?(IO)
        @wait_count += 1
        spawn { copy_io(input, process_input, channel, close_dst: true) }
      else
        @input = process_input
      end
    end

    if needs_pipe?(output)
      process_output, fork_output = IO.pipe(write_blocking: true)
      if output.is_a?(IO)
        @wait_count += 1
        spawn { copy_io(process_output, output, channel, close_src: true) }
      else
        @output = process_output
      end
    end

    if needs_pipe?(error)
      process_error, fork_error = IO.pipe(write_blocking: true)
      if error.is_a?(IO)
        @wait_count += 1
        spawn { copy_io(process_error, error, channel, close_src: true) }
      else
        @error = process_error
      end
    end

    @pid = Process.fork_internal(run_hooks: false) do
      begin
        LibC.setpgrp
        Process.exec_internal(
          command,
          argv,
          env,
          clear_env,
          fork_input || input,
          fork_output || output,
          fork_error || error,
          chdir
        )
      rescue ex
        ex.inspect_with_backtrace STDERR
      ensure
        LibC._exit 127
      end
    end

    proc = -> { waitpid }
    @waitpid_future = Event::SignalChildHandler.instance.wait(pid, proc)

    fork_input.try &.close
    fork_output.try &.close
    fork_error.try &.close
  end

  private def initialize(@pid)
    proc = -> { waitpid }
    @waitpid_future = Event::SignalChildHandler.instance.wait(pid, proc)
    @wait_count = 0
  end

  def waitpid
    @mutex.synchronize do
      ret = LibC.waitpid(pid, out exit_code, LibC::WNOHANG)
      if ret == -1
        raise Errno.new("waitpid") unless Errno.value == Errno::ECHILD
      end
      puts "waitpid #{pid} #{ret}"
      @waited = true if pid == ret
      {ret, exit_code}
    end
  end

  def kill(sig = Signal::TERM)
    kill(sig, @pid)
  end

  def killgroup(sig)
    kill(sig, -@pid)
  end

  private def kill(sig, pid)
    @mutex.synchronize do
      return false if @waited
      Process.kill(sig, pid)
      true
    end
  end
end
