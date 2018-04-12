require "logger"
module Supervisor
  module Logger
    @@logger = ::Logger.new(STDOUT)
    @@stderr = ::Logger.new(STDERR)
    def self.logger
      @@logger
    end

    def self.stderr
      @@stderr
    end

    def logger
      ::Supervisor::Logger.logger
    end

    def stderr
      ::Supervisor::Logger.stderr
    end

    def debug?
      logger.level == ::Logger::DEBUG
    end
  end
end
