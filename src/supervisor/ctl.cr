require "./client"
require "./process_registry"
require "colorize"

module Supervisor
  class Ctl

    def initialize
      @client = Client.new
    end

    def start_process(group, name)
      @client.call("start_process", [group, name])
    end

    def stop_process(group, name)
      @client.call("stop_process", [group, name])
    end

    def start_job(group, job_name)
      processes = job_processes(group, job_name)
      raise "no such job #{job_name}" if processes.size == 0
      processes.each do |group, name|
        puts %(#{"starting".colorize(:green)} #{name} (#{group}))
        start_process(group, name)
      end
    end

    def stop_job(group, job_name)
      processes = job_processes(group, job_name)
      raise "no such job #{job_name}" if processes.size == 0
      processes.each do |group, name|
        puts %(#{"stopping".colorize(:red)} #{name} (#{group}))
        stop_process(group, name)
      end
    end

    def rolling_restart
      @client.call("reload", [Dir.current])
      registry = get_registry_data
      processes = registry[:state]
      current_group = registry[:current_group]
      old_groups = registry[:old_groups]

      unneeded_processes = unneeded_processes(processes, current_group, old_groups)

      unneeded_processes.each do |i|
        group, _, name = i.partition(':')
        puts "removing #{name} (#{group})"
      end
      @client.call("shutdown_processes", unneeded_processes)

      current_processes = processes[current_group]
      current_processes.each do |name, process|
        old_groups.each do |g|
          old_processes = processes[g]
          next if ! old_processes.has_key?(name)
          old_process = old_processes[name]
          group_id = old_process["group_id"]
          puts "#{"stopping".colorize(:red)} #{name} (#{group_id})"
          @client.call("shutdown_process", [old_process["group_id"], old_process["name"]])
        end
        group_id = process["group_id"]
        puts "#{"starting".colorize(:green)} #{name} (#{group_id})"
        @client.call("start_process", [process["group_id"], process["name"]])
      end
      @client.call("remove_old_groups")
    end

    def status
      registry = get_registry_data
      processes = registry[:state]
      current_group = registry[:current_group]
      old_groups = registry[:old_groups]

      template = "| %6s  | %-20s | %-10s | %-5s | %15s |\n"
      line = "-" * 72
      puts "current_group: #{current_group}"
      puts line
      printf template, "group", "name", "state", "pid", "uptime"
      puts line
      processes.each do |group, group_data|
        group_data.each do |name, process|
          uptime = uptime(process[:started_at], process[:state])
          printf template, group, name, process[:state], process[:pid], uptime
        end
      end
      puts line
    end

    def shutdown
      @client.call("shutdown")
    end

    private def uptime(started_at, state)
      return "-" if state !=  State::RUNNING
      uptime = (Time.now.epoch - started_at)
      mm, ss = uptime.divmod(60)
      hh, mm = mm.divmod(60)
      dd, hh = hh.divmod(24)
      if dd == 1
        "%d day, %02d::%02d::%02d" % [dd, hh, mm, ss]
      elsif dd > 1
        "%d days, %02d::%02d::%02d" % [dd, hh, mm, ss]
      else
        "%02d::%02d::%02d" % [hh, mm, ss]
      end
    end

    private def unneeded_processes(state, current_group, old_groups)
      unneeded = [] of String
      current_processes = state[current_group]
      old_groups.each do |g|
        processes = state[g]
        processes.each do |name, _|
          unneeded << "#{g}:#{name}" if ! current_processes.has_key?(name)
        end
      end
      unneeded
    end

    private def job_processes(group, job_name)
      processes = [] of {String, String}
      registry = get_registry_data
      state = registry[:state]
      group_data = state[group]
      group_data.each do |name, _|
        n, match, _ = name.rpartition('_')
        processes << {group, name} if (n == job_name && match == "_")
      end
      processes
    end

    private def get_registry_data
      @client.call("get_registry_data", response_type: RegistryData)
    end
  end
end
