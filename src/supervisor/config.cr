require "./job"

module Supervisor
  module Config

    alias EnvData = Hash(String, String)
    alias JobData = Hash(String, (String | EnvData | Int32 | Bool))
    alias JobsConfig = Array(JobData)
    alias InstancesData = Hash(String, Int32)
    alias OverridesData = Hash(String, JobData)
    alias SvConfig = Hash(String, InstancesData | OverridesData)

    def self.read(dir)
      sv_yml = File.expand_path("config/sv.yml", dir)
      jobs_yml = File.expand_path("config/jobs.yml", dir)
      instances, overrides = read_sv_config(sv_yml)
      group_id, jobs = read_jobs_config(jobs_yml, working_dir: dir, overrides: overrides)
      {instances, group_id, jobs}
    end

    private def self.read_sv_config(path)
      config = Hash(String, InstancesData | OverridesData).from_yaml(File.read(path))
      instances = config.fetch("instances").as(InstancesData)
      overrides = config.fetch("overrides", OverridesData.new).as(OverridesData)
      {instances, overrides}
    end

    private def self.read_jobs_config(path, working_dir, overrides)
      jobs_config = JobsConfig.from_yaml(File.read(path))
      jobs = [] of Job
      group_id = Random::Secure.hex(3)
      jobs_config.each do |job_data|
        job_data["working_dir"] ||= working_dir
        if job_overrides = overrides[job_data["name"]]?
          job_overrides = job_overrides.as(JobData)
          merge_overrides(job_data, job_overrides)
        end
        j = Job.new(job_data, group_id)
        jobs << j
      end
      {group_id, jobs}
    end

    private def self.merge_overrides(job_data, overrides)
      raise "cannot override name" if overrides.has_key? "name"
      override_env = overrides.fetch("env", EnvData.new).as(EnvData)
      env = job_data.fetch("env", EnvData.new).as(EnvData)
      new_env = env.merge(override_env)
      overrides.reject!("env")
      job_data.merge! overrides
      job_data["env"] = new_env
    end
  end
end
