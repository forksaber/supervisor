require "./supervisor/*"
require "json"

module Supervisor
  # TODO Put your code here
end

jobs_config = Array(Hash(String, (String | Hash(String, String) | UInt32 | Bool))).from_json(File.read("config/jobs.yml"))
puts jobs_config
jobs_config.each do |job|
  j = Supervisor::Job.new(job)
  puts j.inspect
  puts j.command
  puts j.stdout_logfile
end
