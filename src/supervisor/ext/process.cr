lib LibC
  fun setpgrp()
end

require "./signal_child_handler"

class Process

  @mutex = Mutex.new
  @waited = false

  def initialize(command : String, args = nil, env = Hash(String, String).new, input : String = "/dev/null", 
                 output : String = "/dev/null", error : String = "/dev/null", chdir : String? = nil)
    command, argv = Process.prepare_argv(command, args, shell: false)
    clear_env = false
    @wait_count = 0
    @pid = Process.fork_internal(run_hooks: false) do
      begin
        LibC.setpgrp
        input_fd = File.open(input, "a+")
        output_fd = File.open(output, "a+")
        error_fd = File.open(error, "a+")
        Process.exec_internal(
          command,
          argv,
          env,
          clear_env,
          input_fd,
          output_fd,
          error_fd,
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
  end

  private def initialize(command : String, args = nil, env : Env = nil, clear_env : Bool = false, shell : Bool = false,
                 input : Stdio = Redirect::Close, output : Stdio = Redirect::Close, error : Stdio = Redirect::Close, chdir : String? = nil)
    @wait_count = 0
    @pid = 0
    @waitpid_future = Concurrent::Future(Process::Status).new do
      Process::Status.new(0)
    end
    raise "initialization disabled intentionally : #{command}"
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
      if pid != ret
        puts "waitpid #{pid} #{ret}"
      end
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
