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
      when "get_state"
        get_state
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
    end

    private def start_process(group_id, name)
      process = @registry.find_process(group_id, name)
      process.start
      {true, ""}
    rescue
      {false, ""}
    end

    private def stop_process(group_id, name)
      process = @registry.find_process(group_id, name)
      process.stop
      {true, ""}
    rescue
      {false, ""}
    end

    private def shutdown_process(group_id, name)
      process = @registry.find_process(group_id, name)
      process.shutdown
      {true, ""}
    rescue
      {false, ""}
    end


    private def get_state
      data = @registry.get_state
      {true, data}
    end

    private def remove_old_groups
      @registry.remove_old_groups
      {true, ""}
    end

    private def start
      {true, ""}
    end

    private def rpc_response(status, data)
      response = {status, data}
      response.to_json
    end

  end
end
