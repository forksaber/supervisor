require "./supervisor/process_registry"
require "./supervisor/server"
require "./supervisor/client"
require "./supervisor/ctl"

module Supervisor

  def self.server
    registry = ProcessRegistry.new
    on_start = ->() { nil }
    server = Server.new(registry)
    setup_signal_handlers(server)
    server.start(on_start)
  end

  def self.fgserver
    registry = Supervisor::ProcessRegistry.new
    on_start = ->() do
      spawn do
        rolling_restart
      rescue
        nil
      end
      nil
    end
    server = Supervisor::Server.new(registry)
    setup_signal_handlers(server)
    server.start(on_start)
  end

  def self.rolling_restart
    ctl = Supervisor::Ctl.new
    ctl.rolling_restart
  end

  def self.status
    ctl = Supervisor::Ctl.new
    ctl.status
    true
  rescue e : Errno
    raise e if ! ( e.errno == Errno::ECONNREFUSED || e.errno == Errno::ENOENT )
    false
  end

  def self.shutdown
    ctl = Supervisor::Ctl.new
    ctl.shutdown
  end

  def self.start_process(group, name)
    ctl = Supervisor::Ctl.new
    ctl.start_process(group, name)
  end

  def self.stop_process(group, name)
    ctl = Supervisor::Ctl.new
    ctl.stop_process(group, name)
  end

  def self.start_job(group, job_name)
    ctl = Supervisor::Ctl.new
    ctl.start_job(group, job_name)
  end

  def self.stop_job(group, job_name)
    ctl = Supervisor::Ctl.new
    ctl.stop_job(group, job_name)
  end

  def self.running?
    UNIXSocket.new("tmp/sv.sock")
    true
  rescue e
    false
  end

  def self.daemon
    daemonize { server }
  end

  private def self.daemonize(&block)
    ::Process.fork do
      STDIN.close
      STDOUT.reopen(File.open("#{Dir.current}/log/sv.log", "a+"))
      STDERR.reopen(File.open("#{Dir.current}/log/sv.log", "a+"))
      C.setsid
      ::Process.fork { yield }
    end
  end

  private def self.setup_signal_handlers(server)
    signals = [Signal::INT, Signal::QUIT, Signal::TERM]
    signals.each do |i|
      i.trap do
        spawn { server.shutdown }
      end
    end
  end
end

lib C
  fun setsid : Int32
end

