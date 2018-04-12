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

      puts "current_group: #{current_group}"
      processes.each do |group, group_data|
        group_data.each do |name, process|
          printf "%10s | %-20s | %5s | %10s\n", group, name, process[:pid], process[:state]
        end
      end
    end
  end
end
