STDIN.blocking = true
STDOUT.blocking = true
STDERR.blocking = true

require "./supervisor"

def start_server
  return if Supervisor.running?
  puts "starting supervisor"
  env = {"GC_UNMAP_THRESHOLD" => "2", "GC_FORCE_UNMAP_ON_GCOLLECT" => "true"}
  path = Process.executable_path
  raise "sv path no found" if ! path
  Process.run path.not_nil!, args: {"server"} , env: env
  loop do
    sleep 0.5
    break if Supervisor.running?
    puts "connecting"
    sleep 1.5
  end
end

abort "no command specified" if ARGV.size == 0
begin
  command = ARGV.shift
  case command
  when "server"
    Supervisor.daemon
  when "fgserver"
    Supervisor.fgserver
  when "rr"
    start_server
    Supervisor.rolling_restart
  when "status"
    Supervisor.status
  when "shutdown"
    Supervisor.shutdown
  else
    puts "unknown command #{command}"
  end
rescue e
  abort e.message
end
