require "socket"
require "json"
require "./net_string"
require "./rpc_api"

module Supervisor
  class Server

    alias CallArgs = Array(String | Int32 | Bool)
    alias RpcRequest = NamedTuple(name: String, args: CallArgs)

    def initialize(process_registry)
      @socket = "tmp/sv.sock"
      @api = RpcApi.new(process_registry)
    end

    def start(on_start : Proc(Void))
      File.delete(@socket) if File.exists? @socket
      UNIXServer.open(@socket) do |server|
        puts "server started on #{@socket}"
        on_start.call
        while client = server.accept?
          spawn handle_client(client, server)
        end
      end
    end

    def shutdown
      ok, _ = @api.handle_call("shutdown", CallArgs.new)
      exit 0 if ok
    end

    private def handle_client(client, server)
      shutdown = loop do
        json = NetString.read(client)
        break false if ! json
        data = RpcRequest.from_json(json)
        name = data[:name]
        args = data[:args]
        response = @api.handle_call(name, args)
        if response
          client << NetString.build(response)
          break true if name == "shutdown" && response[0]
        end
        if name == "reload"
          response = nil
          GC.collect
        end
      end
    rescue e : MalformedNetString
      client.puts "Error: #{e.message}"
    rescue e : JSON::ParseException
      client.puts "Error: invalid json"
    rescue e : Errno
      puts "#{e.class}: #{e.message}"
    ensure
      puts "client disconnected"
      client.close
      if shutdown
        server.close
        exit 0
      end
    end
  end
end
