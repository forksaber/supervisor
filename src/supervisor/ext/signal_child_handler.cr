require "c/sys/wait"
require "signal"
require "./waitid"

module Crystal::SignalChildHandler

  @@waitpid_procs = Hash(LibC::PidT, ->({Int32, Int32})).new
  @@waiting = Hash(LibC::PidT, Channel::Buffered(Int32)).new

  def self.after_fork
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
      ok = waitpid(pid)
      sleep 0.005 if !ok
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

  # calls waitpid_proc for the given pid and sends exit_status to @waitpid channel
  # returns true if waitpid_proc was found for the given pid
  # returns false otherwise

  private def self.waitpid(pid : Int32) : Bool
    waitpid_proc = @@waitpid_procs.fetch(pid, nil)
    return false if !waitpid_proc
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
end
