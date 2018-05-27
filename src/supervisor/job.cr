require "./process_tuple"
require "./command_parser"
module Supervisor
  class Job

    getter name = ""
    getter group_id : String
    getter working_dir = Dir.current
    getter stopsignal = "TERM"

    getter command = ""
    @stdout_logfile = "/dev/null"
    @stderr_logfile = "/dev/null"

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

    def initialize(attrs, group_id)
      update(attrs)
      if @redirect_stderr && ! attrs.has_key?("stderr_logfile")
        @stderr_logfile = @stdout_logfile
      end
      @group_id = group_id
      if @command =~ /\A\.\//
        @command = @command.gsub(/\A\.\//, "#{@working_dir}/")
      end
      @stdout_logfile = absolute_path(@stdout_logfile)
      @stderr_logfile = absolute_path(@stderr_logfile)
    end

    def update(attrs)
      attrs.each do |key, value|
        set key, value
      end
    end

    def to_processes(num_instances)
      arr = [] of Process
      command, args = CommandParser.parse(@command)
      (0..num_instances-1).each do |i|
        t = ProcessTuple.new(
          name: "#{@name}_#{i.to_s.rjust(2, '0')}",
          group_id: @group_id,
          command: command,
          command_args: args,
          working_dir: @working_dir,

          stdout_logfile: @stdout_logfile,
          stderr_logfile: @stderr_logfile,

          env: expand_env(i),
          autorestart: @autorestart,

          stopsignal: Signal.parse(@stopsignal),
          stopasgroup: @stopasgroup,
          killasgroup: @killasgroup,

          startsecs: @startsecs,
          startretries: @startretries,
          stopwaitsecs: @stopwaitsecs
        )
        arr << Process.new(t)
      end
      arr
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

    private def expand_env(process_num)
      vars = {process_num: process_num}
      new_env = {} of String => String
      env.each do |key, value|
        new_env[key] = sprintf(value, vars)
      end
      new_env
    end
  end
end
