require "./supervisor/*"
require "json"

module Supervisor
  # TODO Put your code here
end



jobs_config = Array(Hash(String, (String | Hash(String, String) | Int32 | Bool))).from_json(File.read("config/jobs.yml"))
puts jobs_config

jobs = [] of Supervisor::Job
jobs_config.each do |job|
  j = Supervisor::Job.new(job)
#  puts j.inspect
#  puts j.command
#  puts j.stdout_logfile
  jobs << j
end

channel = Channel(Nil).new

#jobs = [] of Supervisor::Job
process = Supervisor::Process.new(jobs[0])
process.run

2.times do
  channel.receive
end
