require 'yaml'
require 'java-properties'
require 'fileutils'
require_relative 'distribute'
require_relative '../client'

module Tes::Request::RSpec
  class CiSlicer
    SUPPORT_FILE_TYPES = [:yaml, :yml, :json, :properties]

    def initialize(file_type, project_dir, res_replace_map_json_file = nil, pool_url = nil)
      unless SUPPORT_FILE_TYPES.include?(file_type.to_sym)
        raise(ArgumentError, "Not supported file type:#{file_type}!")
      end

      @cfg_file_type = file_type
      @project_dir = project_dir
      @res_addition_attr_map = (res_replace_map_json_file && JSON.parse(File.read(res_replace_map_json_file)))
      @cfg_target_dir = File.join(@project_dir, '.ci_jobs')
      @pool_url = pool_url
    end

    def run(ci_type, slice_count)
      puts "Generate RSpec distribute jobs #{@cfg_file_type} file for CI"
      rspec_distribute = Distribute.new(@project_dir)
      pool = if @pool_url
               driver = HTTPClient.new(base_url: @pool_url)
               driver.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
               client = ::Tes::Request::Client.new(driver)
               @pool = client.get_all_res
             else
               {}
             end
      jobs = rspec_distribute.distribute_jobs(ci_type, slice_count, @res_addition_attr_map, pool)
      save_job_files(jobs, @cfg_target_dir, @cfg_file_type)
      @cfg_target_dir
    end

    def rspec_tag_param_str(tags)
      case tags
      when Array
        tags.map {|t| "--tag #{t}"}.join(' ')
      when String
        "--tag #{tags}"
      when nil
        nil
      else
        raise("不支持的类型:#{tags.class}")
      end
    end

    def pytest_mark_param_str(tags)
      case tags
      when Array
        if tags.empty?
          nil
        elsif tags.size > 1
          total_tag_str = tags.map {|t| t =~ /\S+\s+\S+/ ? "(#{t})" : t}.join(' or ')
          "-m '#{total_tag_str}'"
        else
          tag = tags.first
          (tag =~ /\S+\s+\S+/) ? "-m '#{tag}'" : "-m #{tag}"
        end

      when String
        (tags =~ /\S+\s+\S+/) ? "-m '#{tags}'" : "-m #{tags}"
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

      job_configs_for_ci = jobs.map {|j| gen_job_ci_params(j)}
      FileUtils.rm_rf(target_dir)
      FileUtils.mkdir(target_dir)
      case file_type
      when :json
        save_file = File.join(target_dir, 'ci_tasks.json')
        File.open(save_file, 'w') {|f| f.write job_configs_for_ci.to_json}
        puts "Generated #{jobs.size} jobs, Stored in:#{save_file} ."
      when :yml, :yaml
        save_file = File.join(target_dir, 'ci_tasks.yml')
        File.open(save_file, 'w') {|f| f.write job_configs_for_ci.to_yaml}
        puts "Generated #{jobs.size} jobs, Stored in:#{save_file} ."
      when :properties
        job_configs_for_ci.each_with_index do |params, i|
          file = File.join(target_dir, "#{i}.properties")
          JavaProperties.write(params, file)
        end
        puts "Generated #{jobs.size} jobs, Stored in:#{target_dir}/*.properties ."
      end
    end

    def get_job_rspec_run_args_str(job, split = ' ')
      if job[:specs].any? {|s| s.match(/_spec.rb\b/)}
        tags_str = rspec_tag_param_str(job[:tag])
      elsif job[:specs].any? {|s| s.match(/_test.py\b/) or s.match(/test_\w+.py\b/)}
        tags_str = pytest_mark_param_str(job[:tag])
      end
      paths_str = job[:specs].join(split)
      tags_str ? (tags_str + split + paths_str) : paths_str
    end

    def get_job_env_profile_str(job, split = ';')
      job[:profile].to_s(split)
    end

    private

    def gen_job_ci_params(job)
      {'RSPEC_PARAM' => get_job_rspec_run_args_str(job), 'REQUEST_ASKS' => get_job_env_profile_str(job)}
    end
  end
end