require 'rake'
require 'rake/tasklib'
require 'yaml'
require 'java-properties'
require_relative 'rspec/distribute'

class Tes::Request::RakeTask < ::Rake::TaskLib
  SUPPORT_FILE_TYPES = [:yaml, :yml, :json, :properties]

  def initialize(name, type)
    desc "Generate RSpec distribute jobs #{type} file for CI"
    task name, [:project_dir, :type, :count, :version, :lang] do |_, task_args|
      rspec_distribute = ::Tes::Request::RSpec::Distribute.new(task_args[:project_dir])
      jobs = rspec_distribute.distribute_jobs(task_args[:type],
                                              task_args[:count].to_i,
                                              task_args[:version],
                                              task_args[:lang])
      target_dir = File.join(task_args[:project_dir], '.ci_jobs')
      save_job_files(jobs, target_dir, type)
    end
  end

  def spec_tag_param_str(tags)
    case tags
      when Array
        tags.map { |t| "--tag #{t}" }.join(' ')
      when String
        "--tag #{tags}"
      when nil
        nil
      else
        raise("不支持的类型:#{tags.class}")
    end
  end

  def save_job_files(jobs, target_dir, file_type)
    unless SUPPORT_FILE_TYPES.include?(file_type)
      raise(ArgumentError, "Not supported file type:#{file_type}!")
    end

    job_configs_for_ci = jobs.map { |j| gen_job_ci_params(j) }
    FileUtils.rm_rf(target_dir)
    FileUtils.mkdir(target_dir)
    case file_type
      when :json
        save_file = File.join(target_dir, 'ci_tasks.json')
        File.open(save_file, 'w') { |f| f.write job_configs_for_ci.to_json }
        puts "Generated #{jobs.size} jobs, Stored in:#{save_file} ."
      when :yml, :yaml
        save_file = File.join(target_dir, 'ci_tasks.yml')
        File.open(save_file, 'w') { |f| f.write job_configs_for_ci.to_yaml }
        puts "Generated #{jobs.size} jobs, Stored in:#{save_file} ."
      when :properties
        job_configs_for_ci.each_with_index do |params, i|
          file = File.join(target_dir, "#{i}.properties")
          save_job_properties(params, file)
        end
        puts "Generated #{jobs.size} jobs, Stored in:#{target_dir}/*.properties ."
    end
  end

  def save_job_properties(job_cfg, save_file)
    # context = ["# gen at #{Time.now}"]
    JavaProperties.write(job_cfg, save_file)
    #
    # context = ["# gen at #{Time.now}"]
    # tag_opt_cli_args = spec_tag_param_str(job_cfg[:tag])
    # rspec_param = if tag_opt_cli_args
    #                 "RSPEC_PARAM = #{tag_opt_cli_args} \\\n\t#{piece[:files].join(" \\\n\t")}"
    #               else
    #                 "RSPEC_PARAM = #{piece[:files].join(" \\\n\t")}"
    #               end
    # context << "REQUEST_ASKS = #{piece[:profile].to_s(";\\\n\t")}"
    # File.open(file, 'w') { |f| f.write context.join("\n") }
  end

  def get_job_rspec_run_args_str(job, split=' ')
    tags_str = spec_tag_param_str(job[:tag])
    paths_str = job[:specs].join(split)
    tags_str ? (tags_str + split + paths_str) : paths_str
  end

  def get_job_env_profile_str(job, split=';')
    job[:profile].to_s(split)
  end

  def gen_job_ci_params(job)
    {'RSPEC_PARAM' => get_job_rspec_run_args_str(job), 'REQUEST_ASKS' => get_job_env_profile_str(job)}
  end
end