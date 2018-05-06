require "./process_registry"
module Supervisor
  class RpcApi

    @registry : ProcessRegistry

    def initialize(@registry)
    end

    def handle_call(method, args)
      response = case method
      when "reload"
        reload
      when "start"
        start
      when "get_registry_data"
        get_registry_data
      when "start_process"
        group_id = args[0]
        name = args[1]
        start_process(group_id, name)
      when "stop_process"
        group_id = args[0]
        name = args[1]
        stop_process(group_id, name)
      when "shutdown_process"
        group_id = args[0]
        name = args[1]
        shutdown_process(group_id, name)
      when "shutdown_processes"
        processes = args
        shutdown_processes(processes)
      when "remove_old_groups"
        remove_old_groups
      else
        {false, "unknown method #{method}"}
      end
      rpc_response(response[0], response[1])
    end

    private def reload
      @registry.reload
      {true, ""}
    rescue e
      {false, e.message}
    end

    private def start_process(group_id, name)
      process = @registry.find_process(group_id, name)
      ok, _, _ = process.start
      {ok, ""}
    rescue
      {false, ""}
    end

    private def stop_process(group_id, name)
      process = @registry.find_process(group_id, name)
      ok, _, _ = process.stop
      {ok, ""}
    rescue
      {false, ""}
    end

    private def shutdown_process(group_id, name)
      process = @registry.find_process(group_id, name)
      ok = process.shutdown
      {ok, ""}
    rescue
      {false, ""}
    end

    private def shutdown_processes(processes)
      count = processes.size
      chan = Channel({Bool, String, String}).new(count)
      processes.each do |i|
        group, _,  name = i.as(String).partition(':')
        process = @registry.find_process(group, name)
        spawn { ok = process.shutdown; chan.send({ok, group, name}) }
      end

      errors = [] of String
      count.times do |i|
        ok, group, name = chan.receive
        errors << "#{group}:#{name}" if ! ok
      end
      if errors.size == 0
        {true, ""}
      else
        {false, "#{errors.join(", ")}"}
      end
    rescue e
      {false, e.message}
    end

    private def get_registry_data
      data = @registry.get_registry_data
      {true, data}
    end

    private def remove_old_groups
      @registry.remove_old_groups
      {true, ""}
    end

    private def start
      @registry.reopen
      {true, ""}
    end

    private def rpc_response(status, data)
      response = {status, data}
      response.to_json
    end

  end
end
