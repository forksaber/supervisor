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
  process = Process.new path.not_nil!, args: {"server"}, env: env, input: "/dev/null"
  process.wait
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
    ok = Supervisor.status
    puts "Stopped" if ! ok
  when "shutdown"
    Supervisor.shutdown
  when "start"
    arg = ARGV.shift
    abort "expected argument <group>:<name>" if ! arg
    group, _, name = arg.partition(':')
    Supervisor.start_process(group, name)
  when "stop"
    arg = ARGV.shift
    abort "expected argument <group>:<name>" if ! arg
    group, _, name = arg.partition(':')
    Supervisor.stop_process(group, name)
  when "start_job"
    arg = ARGV.shift
    abort "expected argument <job_name>" if ! arg
    group, _, job_name = arg.partition(':')
    Supervisor.start_job(group, job_name)
  when "stop_job"
    arg = ARGV.shift
    abort "expected argument <job_name>" if ! arg
    group, _, job_name = arg.partition(':')
    Supervisor.stop_job(group, job_name)
  else
    puts "unknown command #{command}"
  end
rescue e
  abort e.message
end
