require "./client"
require "./process_registry"

module Supervisor
  class Ctl

    def initialize
      @client = Client.new
    end

    def rolling_restart
      @client.call("reload")
      registry = get_state
      processes = registry[:state]
      current_group = registry[:current_group]
      old_groups = registry[:old_groups]

      current_processes = processes[current_group]
      current_processes.each do |name, process|
        old_groups.each do |g|
          old_processes = processes[g]
          next if ! old_processes.has_key?(name)
          old_process = old_processes[name]
          group_id = old_process["group_id"]
          puts "stopping #{group_id} -> #{name}"
#          @client.call("shutdown_process", [old_process["group_id"], old_process["name"]])
        end
        group_id = process["group_id"]
        puts "starting #{group_id} -> #{name}"
        @client.call("start_process", [process["group_id"], process["name"]])
      end
      @client.call("remove_old_groups")
    end

    def get_state
      @client.call2("get_state")
    end

    def status
      registry = get_state
      processes = registry[:state]
      current_group = registry[:current_group]
      old_groups = registry[:old_groups]

      template = "| %-20s | %-10s | %-5s | %15s | %6s |\n"

      puts "current_group: #{current_group}"
      puts "-" * 72
      printf template, "name", "state", "pid", "uptime", "group"
      puts "-" * 72
      processes.each do |group, group_data|
        group_data.each do |name, process|
          uptime = uptime(process[:started_at], process[:state])
          printf template, name, process[:state], process[:pid], uptime, group
        end
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

  end
end
