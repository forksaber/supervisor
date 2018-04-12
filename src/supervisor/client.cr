require "socket"
require "json"
require "./net_string"

module Supervisor
  class Client

    alias RpcResponse = NamedTuple(status: String, data: JSON)
    alias CallArgs = Array(String | Bool | Int32)
    alias ParseType = (JSON::Any | String)

    def initialize
      @server_path = "tmp/sv.sock"
    end

    def call(name : String, args = CallArgs.new)
      ok, data = rpc_call(name, args)
      if ! ok
        raise RpcException.new("Error in call #{name}(#{args}): #{data}")
      end
      data
    end

    def call2(name : String, args = CallArgs.new)
      ok, data = rpc_call2(name, args)
      if ! ok
        raise RpcException.new("Error in call #{name}(#{args}): #{data}")
      end
      data
    end

    def call_safe(name : String, args = CallArgs.new, parse_type = ParseType)
      rpc_call(name, args, parse_type)
    end

    private def rpc_call(name : String, args : CallArgs) : {Bool, (JSON::Any | String)}
      json = {name: name, args: args}.to_json
      connection << NetString.build(json)
      response = NetString.read(connection)
      if ! response
        return {false, "EOFError"}
      end
      t = Tuple(Bool, ParseType).from_json(response)
      return t
    rescue e : MalformedNetString
      message = e.message || "malformed net string"
      {false, message}
    rescue e : JSON::ParseException
      {false, "json parse error"}
    end

    private def rpc_call2(name : String, args : CallArgs) : {Bool, SerializedRegistry}
      json = {name: name, args: args}.to_json
      connection << NetString.build(json)
      response = NetString.read(connection)
      if ! response
        return {false, SerializedRegistry.new(current_group: "", old_groups: Array(String).new, state: SerializedState.new)}
#        return {false, SerializedRegistry.new}
      end
      t = Tuple(Bool, SerializedRegistry).from_json(response)
      return t
#    rescue e : MalformedNetString
#      message = e.message || "malformed net string"
#      {false, message}
#    rescue e : JSON::ParseException
#      {false, "json parse error"}
    end

    private def connection
      @connection ||= UNIXSocket.new(@server_path)
    end
  end
  class RpcException < ::Exception
  end
end
