require "c/sys/wait"
require "signal"
require "./waitid"

module Crystal::SignalChildHandler

  @@waitpid_procs = Hash(LibC::PidT, ->({Int32, Int32})).new
  @@waiting = Hash(LibC::PidT, Channel::Buffered(Int32)).new
  @@mutex = Mutex.new

  def self.mutex
    @@mutex
  end

  def self.after_fork
    @@mutex = Mutex.new
    @@waitpid_procs.clear
    @@waiting.each_value(&.close)
    @@waiting.clear
  end

  def self.wait(pid : LibC::PidT, waitpid_proc) : Channel::Buffered(Int32)
    chan = Channel::Buffered(Int32).new(1)
    @@waiting[pid] = chan
    @@waitpid_procs[pid] = waitpid_proc
    chan
  end

  def self.call
    loop do
      pid = waitid
      return if pid == 0
      waitpid(pid)
    end
  end

  # calls waitid and returns a pid which needs to be waited upon
  # returns 0 if no waitable pid is found

  private def self.waitid : Int32
    siginfo = LibC::SigInfoT.new
    siginfo.si_pid = 0
    infop = pointerof(siginfo)
    ret = LibC.waitid(LibC::IdTypeT::P_ALL, 0, infop, LibC::WNOHANG | LibC::WNOWAIT | LibC::WEXITED)
    if ret == 0
      pid = siginfo.si_pid
      return pid
    else
      raise Errno.new("waitid") unless Errno.value == Errno::ECHILD
      return 0
    end
  end

  private def self.waitpid(pid : Int32) : Bool
    if registered?(pid)
      waitpid_registered(pid)
    else
      waitpid_unregistered(pid)
    end
  end

  private def self.registered?(pid : Int32)
    @@mutex.synchronize do
      @@waiting.has_key?(pid) && @@waitpid_procs.has_key?(pid)
    end
  end

  # calls waitpid_proc for the given pid and sends exit_status to @waitpid channel
  # returns true if waitpid_proc was found for the given pid
  # returns false otherwise

  private def self.waitpid_registered(pid : Int32)
    waitpid_proc = @@waitpid_procs[pid]
    chan = @@waiting[pid]
    ret, exit_code = waitpid_proc.call
    if ret == pid
      chan = @@waiting[pid]
      chan.send exit_code
      chan.close
      @@waiting.delete(pid)
      @@waitpid_procs.delete(pid)
    end
    return true
  end

  private def self.waitpid_unregistered(pid : Int32)
    ret = LibC.waitpid(pid, out exit_code, LibC::WNOHANG)
    if ret == -1
      raise Errno.new("waitpid") unless Errno.value == Errno::ECHILD
    end
    STDERR.puts "not registered #{pid} #{ret}"
    return true
  end
end
