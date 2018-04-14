require "socket"
require "json"
require "./net_string"

module Supervisor
  class Client

    alias CallArgs = Array(String | Bool | Int32)

    def initialize
      @server_path = "tmp/sv.sock"
    end

    def call(name : String, args = CallArgs.new, response_type : T.class = JSON::Any) forall T
      response = rpc_call(name, args)
      ok, data = Tuple(Bool, T).from_json(response)
      if ! ok
        raise RpcException.new("Error in call #{name}(#{args}): #{data}")
      end
      data
    rescue e : JSON::ParseException
      raise RpcException.new(e.message)
    end

    private def rpc_call(name : String, args : CallArgs)
      json = {name: name, args: args}.to_json
      connection << NetString.build(json)
      response = NetString.read(connection)
      raise RpcException.new("connection closed before sending response") if ! response
      response
    rescue e : MalformedNetString
      raise RpcException.new(e.message)
    end

    private def connection
      @connection ||= UNIXSocket.new(@server_path)
    end
  end
  class RpcException < ::Exception
  end
end
