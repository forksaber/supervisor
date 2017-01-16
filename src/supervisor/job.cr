module Supervisor
  class Job
    STRING_ATTRS = ["name", "working_dir", "stopsignal", "command", "stdout_logfile", "stderr_logfile"]
    BOOL_ATTRS   = ["autorestart", "stopasgroup", "killasgroup", "redirect_stderr"]
    HASH_ATTRS   = ["env"]
    INT_ATTRS    = ["numprocs", "startsecs", "startretries", "stopwaitsecs"]

    getter :name, :working_dir, :stopsignal
    {% for i in BOOL_ATTRS %}
    getter {{i}}
    {% end %}

    {% for i in INT_ATTRS %}
    getter {{i}}
    {% end %}

    getter :env
    @name : String

    def initialize(attrs)
      @name = ""
      @command = ""
      @working_dir = Dir.current
      @stdout_logfile = "/dev/null"
      @stderr_logfile = ""
      @stopsignal = "TERM"

      @env = {} of String => String

      @autorestart = true
      @stopasgroup = false
      @killasgroup = true
      @redirect_stderr = true

      @numprocs = 0_u32
      @startsecs = 1_u32
      @startretries = 3_u32
      @stopwaitsecs = 10_u32
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
      absolute_path @stderr_logfile
    end

    private def update(attrs)
      {% for ivar, i in @type.instance_vars %}
        puts "@{{ivar.type}}"
      {% end %}
      puts {{@type}}
      attrs.each do |key, value|
        set key, value
      end
    end

    private def set(key, value)
      case key
      when "name"
        @name = value.as(String)
      when "command"
        @command = value.as(String)
      when "working_dir"
        @working_dir = value.as(String)
      when "stdout_logfile"
        @stdout_logfile = value.as(String)
      when "stderr_logfile"
        @stderr_logfile = value.as(String)
      when "stopsignal"
        @stopsignal = value.as(String)
      when "autorestart"
        @autorestart = value.as(Bool)
      when "stopasgroup"
        @stopasgroup = value.as(Bool)
      when "killasgroup"
        @killasgroup = value.as(Bool)
      when "redirect_stderr"
        @redirect_stderr = value.as(Bool)
      when "numprocs"
        @numprocs = value.as(UInt32)
      when "startsecs"
        @startsecs = value.as(UInt32)
      when "startretries"
        @startretries = value.as(UInt32)
      when "stopwaitsecs"
        @stopwaitsecs = value.as(UInt32)
      when "env"
        @env = value.as(Hash(String, String))
      else
        raise "no such key #{key}"
      end
    end

    private def absolute_path(path)
      File.expand_path(path, @working_dir)
    end
  end
end
