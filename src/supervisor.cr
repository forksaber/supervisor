require "./supervisor/process_registry"
require "./supervisor/server"
require "./supervisor/client"
require "./supervisor/ctl"

module Supervisor

  def self.server
    registry = ProcessRegistry.new
    on_start = ->() { nil }
    server = Server.new(registry)
    server.start(on_start)
  end

  def self.fgserver
    registry = Supervisor::ProcessRegistry.new
    on_start = ->() do
      spawn do
        rolling_restart
      end
      nil
    end
    server = Supervisor::Server.new(registry)
    server.start(on_start)
  end

  def self.rolling_restart
    ctl = Supervisor::Ctl.new
    ctl.rolling_restart
  end

  def self.status
    ctl = Supervisor::Ctl.new
    ctl.status
  end

  def self.shutdown
    ctl = Supervisor::Ctl.new
    ctl.shutdown
  end
end
