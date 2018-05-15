STDIN.blocking = true
STDOUT.blocking = true
STDERR.blocking = true

lib C
  fun setsid : Int32
end

def daemon(&block)
  Process.fork do
    STDIN.close
    STDOUT.reopen(File.open("#{Dir.current}/log/sv.log", "a+"))
    STDERR.reopen(File.open("#{Dir.current}/log/sv.log", "a+"))
    C.setsid
    Process.fork { yield }
  end
end

require "./supervisor"
abort "no command specified" if ARGV.size == 0
begin
  command = ARGV.shift
  case command
  when "server"
  #  daemon do
  #    set_nproc 1
      Supervisor.server
  #  end
  when "fgserver"
    Supervisor.fgserver
  when "rr"
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
