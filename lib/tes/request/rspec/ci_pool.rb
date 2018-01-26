require 'yaml'
require 'fileutils'
require_relative 'distribute'
require_relative '../client'

module Tes::Request::RSpec
  class CiPool
    SUPPORT_FUNCTIONS = %i[satisfy]

    def initialize(tes_pool_url, pool_func) #
      @pool_url = tes_pool_url
      @pool_func = pool_func
      driver = HTTPClient.new(base_url: tes_pool_url)
      driver.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
      client = ::Tes::Request::Client.new(driver)
      @pool = client.get_all_res
    end

    def run(*args)
      send(@pool_func, *args)
    end

    def satisfy(project_dir, ci_type, res_replace_map_json_file=nil)
      res_addition_attr_map = (res_replace_map_json_file && JSON.parse(File.read(res_replace_map_json_file)))
      rspec_distribute = Distribute.new(project_dir)
      jobs = rspec_distribute.distribute_jobs(ci_type, 1, res_addition_attr_map)
      not_satisfied_profiles = jobs.inject([]) do |t, job|
        t << job[:profile] unless job[:profile].request(@pool).all?
        t
      end
      unless not_satisfied_profiles.empty?
        warn <<EOF
!!!No matched resources in pool for profiles ==>

#{not_satisfied_profiles.join("\n------------------\n")}
~~~~~~~~~~~~~~~~~~~~~~~!!!
EOF
        raise('No matched resources in pool')
      end
    end
  end
end