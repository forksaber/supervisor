require "c/sys/wait"
require "event/signal_child_handler"
require "./waitid"

class Event::SignalChildHandler

  def initialize
    @waitpid_procs = Hash(LibC::PidT, ->({Int32, Int32})).new
    @waiting = Hash(LibC::PidT, ChanType).new
  end

  def after_fork
    @waitpid_procs.clear
    @waiting.each { |pid, chan| chan.send(nil) }
    @waiting.clear
  end

  def wait(pid, waitpid_proc)
    chan = ChanType.new(1)
    @waiting[pid] = chan
    @waitpid_procs[pid] = waitpid_proc

    lazy do
      chan.receive || raise Channel::ClosedError.new("waitpid channel closed after forking")
    end
  end

  def trigger
    loop do
      pid = waitid
      return if pid == 0
      ok = waitpid(pid)
      sleep 0.005 if !ok
    end
  end

  # calls waitid and returns a pid which needs to be waited upon
  # returns 0 if no waitable pid is found

  private def waitid : Int32
    siginfo = LibC::SigInfoT.new
    siginfo.si_pid = 0
    infop = pointerof(siginfo)
    ret = LibC.waitid(LibC::IdTypeT::P_ALL, 0, infop, LibC::WNOHANG | LibC::WNOWAIT | LibC::WEXITED)
    puts siginfo
    if ret == 0
      pid = siginfo.si_pid
      return pid
    else
      raise Errno.new("waitid") unless Errno.value == Errno::ECHILD
      return 0
    end
  end

  # calls waitpid_proc for the given pid and completes the waitpid_future
  # returns true if waitpid_proc was found for the given pid
  # returns false otherwise

  private def waitpid(pid : Int32) : Bool
    waitpid_proc = @waitpid_procs.fetch(pid, nil)
    return false if !waitpid_proc
    ret, exit_code = waitpid_proc.call
    if ret == pid
      chan = @waiting[pid]
      chan.send Process::Status.new(exit_code)
      @waiting.delete(pid)
      @waitpid_procs.delete(pid)
    end
    return true
  end
end
