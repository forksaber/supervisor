require "yaml"
require "./process"
require "./config"

module Supervisor

  alias GroupData = Hash(String, ProcessData)
  alias StateData = Hash(String, GroupData)
  alias RegistryData = NamedTuple(state: StateData, current_group: String, old_groups: Array(String))

  class ProcessRegistry

    alias State = Hash(String, Hash(String, Process))

    @state : State
    @current_group : String

    def initialize
      @state = State.new
      @current_group = ""
      @old_groups = [] of String
    end

    def find_process(group_id, name)
      group = @state[group_id]
      group[name]
    end

    def reopen
      pr = @state[@current_group].values.first
      pr.reopen_logs
    end

    def get_registry_data
      data = StateData.new
      @state.each do |group, group_data|
        h = GroupData.new
        group_data.each do |name, process|
          h[name] = process.to_h
        end
        data[group] = h
      end
      RegistryData.new(state: data, current_group: @current_group, old_groups: @old_groups)
    end

    def reload(dir)
      instances, group_id, jobs = Config.read(dir)
      jobs.each do |j|
        n = instances.fetch(j.name, 0).as(Int32)
        next if n <= 0
        processes = j.to_processes(n)
        h = {} of String => Process
        processes.each { |i| h[i.name] = i }
        @state[group_id] = h
      end
      if ! @current_group.empty?
        @old_groups << @current_group
      end
      @current_group = group_id
    end

    def remove_old_groups
      chan = Channel({Bool, String, String}).new
      count = 0
      @old_groups.each do |i|
        group_data = @state[i]
        group_data.each do |name, process|
          count += 1
          spawn { ok = process.shutdown; chan.send({ok, i, name}) }
        end
      end
      count.times do
        ok, group, name = chan.receive
        @state[group].delete(name) if ok
      end

      @old_groups.each do |i|
        group_data = @state.has_key?(i) ? @state[i] : GroupData.new
        if group_data.empty?
          @state.delete(i)
          @old_groups.delete(i)
        end
      end
    end
  end
end
