module Supervisor
  class Job

    getter name = ""
    getter working_dir = Dir.current
    getter stopsignal = "TERM"

    @command = ""
    @stdout_logfile = "/dev/null"
    @stderr_logfile : (String | Nil) = nil

    getter env = {} of String => String

    getter autorestart = true
    getter stopasgroup = false
    getter killasgroup = true
    getter redirect_stderr = true

    getter startsecs = 1
    getter startretries = 3
    getter stopwaitsecs = 10

    def_hash @name, @working_dir, @stdout_logfile,
             @stderr_logfile, @redirect_stderr

    def initialize(attrs)
      update(attrs)
    end

    def command
      return @command if !@command =~ /\A\.\//
      @command.gsub(/\A\.\//, "#{@working_dir}/")
    end

    def stdout_logfile
      absolute_path @stdout_logfile
    end

    def stderr_logfile
      @stderr_logfile ? absolute_path(@stderr_logfile.as(String)) : nil
    end

    def update(attrs)
      attrs.each do |key, value|
        set key, value
      end
    end

    private def set(key, value)
      {% begin %}
      case key
      {% for ivar in @type.instance_vars %}
      when "{{ivar.id}}"
        @{{ivar.id}} = value.as({{ivar.type}})
      {% end %}
      else
        raise "no such key #{key}"
      end
      {% end %}
    end

    private def absolute_path(path)
      File.expand_path(path, @working_dir)
    end

  end
end
