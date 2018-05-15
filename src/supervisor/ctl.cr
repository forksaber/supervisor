require "./client"
require "./process_registry"
require "colorize"

module Supervisor
  class Ctl

    def initialize
      @client = Client.new
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

      template = "| %-20s | %-10s | %-5s | %15s | %6s |\n"
      line = "-" * 72
      puts "current_group: #{current_group}"
      puts line
      printf template, "name", "state", "pid", "uptime", "group"
      puts line
      processes.each do |group, group_data|
        group_data.each do |name, process|
          uptime = uptime(process[:started_at], process[:state])
          printf template, name, process[:state], process[:pid], uptime, group
        end
      end
      puts line
    end

    def shutdown
      @client.call("shutdown")
    end

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

    private def get_registry_data
      @client.call("get_registry_data", response_type: RegistryData)
    end
  end
end
