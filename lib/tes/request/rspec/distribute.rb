require 'yaml'
require 'json'
require_relative 'profile_parser'

module Tes
  module Request
    module RSpec
      class Distribute
        include Function

        DEFAULT_CI_YAML_FILE = '.ci.yaml'
        EXCLUDE_CLUSTER_RES_PATTERN_PROFILE = '.ci_exclude_res_pattern'

        @@ci_yaml_file = DEFAULT_CI_YAML_FILE
        @@ci_exclude_cluster_pattern_file = EXCLUDE_CLUSTER_RES_PATTERN_PROFILE

        # @param [String] project_dir 测试项目的根目录路径
        # @param [String] ci_yaml_file 测试项目内的描述spec测试的配置文件路径(相对`project_dir`)
        def initialize(project_dir, ci_yaml_file = @@ci_yaml_file)
          @project_dir = project_dir
          @ci_cfg = YAML.load_file(File.join(@project_dir, ci_yaml_file))
        end

        attr_reader :project_dir, :ci_cfg

        # 生成分发任务的配置结构
        # @param [String] type task type
        # @param [Integer] count 分批任务数
        # @param [Hash] res_addition_attr_map 资源属性需要调整的映射表
        # @param [Hash,nil] adapt_pool
        # @return [Array<Hash>]
        def distribute_jobs(type, count, res_addition_attr_map = {}, adapt_pool = {})
          task_cfg = get_rspec_task(type)
          spec_paths = spec_files(type)
          rspec_parser = Tes::Request::RSpec::ProfileParser.new(spec_paths)
          rspec_parser.parse_profiles!
          rspec_profiles = rspec_parser.profiles

          if res_addition_attr_map and res_addition_attr_map.size > 0
            rspec_profiles.each do |spec|
              res_addition_attr_map.each do |res_filter_pattern, attr_add_map|
                request_asks = spec[:profile].data.select {|ask| ask.to_s.include? res_filter_pattern}
                request_asks.each do |ask|
                  # only add the resource attribution when no request the attribution for the resource
                  attr_add_map.each do |attr_name, attr_limit|
                    unless ask.data.include?(attr_name)
                      ask.data[attr_name] = Tes::Request::Expression.new("#{attr_name}#{attr_limit}")
                    end
                  end
                end
              end
            end
          end


          if adapt_pool and adapt_pool.size > 0
            rspec_profiles.delete_if do |spec|
              pool_not_satisfied = !(spec[:profile].request(adapt_pool).all?)
              warn "POOL is not satisfied for: #{spec[:file]}" if pool_not_satisfied
              pool_not_satisfied
            end
          end

          gen_pieces(rspec_profiles, count).map do |piece|
            profile = piece[:profile]
            specs = piece[:specs].inject([]) do |t, spec|
              file_path = spec[:file].sub(/^#{@project_dir}/, '').sub(/^\//, '')
              if (spec[:locations] and spec[:locations].size > 0) or (spec[:ids] and spec[:ids].size > 0)
                if spec[:locations] and spec[:locations].size > 0
                  t.push(file_path + ':' + spec[:locations].join(':'))
                end
                if spec[:ids] and spec[:ids].size > 0
                  t.push(file_path + '[' + spec[:ids].join(',') + ']')
                end
              else
                t.push file_path
              end
              t
            end

            {profile: profile, specs: specs}
          end.map {|p| p.merge(tag: task_cfg['tag'])}
        end

        private

        # 生产任务碎片,尽量接近传递的参数值
        # @param [Fixnum] minimum_pieces
        # @return [Array]
        def gen_pieces(profiles, minimum_pieces)
          common_jobs = []
          standalone_jobs = []
          min_spec_count = profiles.size / minimum_pieces

          profiles.sort_by {rand}.each do |to_merge_spec|
            # 0. 任务发布要求的特殊处理
            if to_merge_spec[:distribute] && to_merge_spec[:distribute][:standalone]
              standalone_jobs << {profile: to_merge_spec[:profile], specs: [to_merge_spec]}
              next
            end

            # 1. 优先相同要求的归并
            join_piece = common_jobs.select do |piece|
              piece[:specs].size <= min_spec_count and
                  piece[:profile] == to_merge_spec[:profile]
            end.sample
            if join_piece
              join_piece[:specs] << to_merge_spec
            else
              # 2. 然后再是资源多少不同的归并
              super_piece = common_jobs.select do |piece|
                if piece[:specs].size <= min_spec_count
                  cr = piece[:profile] <=> to_merge_spec[:profile]
                  cr && cr >= 0
                else
                  false
                end
              end.sample
              if super_piece
                super_piece[:specs] << to_merge_spec
              else
                # 3. 可整合计算的的归并,但要求已经达到的任务分片数已经达到了要求那么大,否则直接以新建来搞
                if common_jobs.size >= minimum_pieces
                  merge_piece = common_jobs.select do |piece|
                    piece[:specs].size <= min_spec_count and
                        piece[:profile].merge_able?(to_merge_spec[:profile])
                  end.sample
                  if merge_piece
                    merge_piece[:profile] = merge_piece[:profile] + to_merge_spec[:profile]
                    merge_piece[:specs] << to_merge_spec
                  else
                    # 4. 最后再尝试独立出一个新的piece,在剩余数量达到一半要求的时候
                    common_jobs << {profile: to_merge_spec[:profile], specs: [to_merge_spec]}
                  end
                else
                  common_jobs << {profile: to_merge_spec[:profile], specs: [to_merge_spec]}
                end
              end
            end
          end
          standalone_jobs + common_jobs
        end


        # @param [String] type
        # @return [Hash] rspec ci task info
        def get_rspec_task(type)
          raise("No CI Task:#{type}") unless @ci_cfg.key?(type)
          @ci_cfg[type]
        end

        # @return [Array<String>]
        def spec_files(task_type)
          spec_cfg = get_rspec_task(task_type)['spec']
          spec_paths = filter_spec_by_path(spec_cfg['pattern'], spec_cfg['exclude_pattern'])

          exclude_cluster_profile_file = File.join(@project_dir, @@ci_exclude_cluster_pattern_file)
          if File.exists?(exclude_cluster_profile_file)
            exclude_patterns = File.readlines(exclude_cluster_profile_file).map(&:strip)
            exclude_spec_by_resource(spec_paths, exclude_patterns)
          else
            spec_paths
          end
        end

        # @return [Array<String>]
        def filter_spec_by_path(pattern, exclude_pattern = nil)
          pattern_filter_lab = ->(p) do
            spec_info = get_spec_path_info(p)
            direct_return = (spec_info[:locations] or spec_info[:ids])
            direct_return ? [File.join(@project_dir, p)] : Dir[File.join(@project_dir, p)]
          end

          ret = case pattern
                when String
                  pattern_filter_lab.call(pattern)
                  Dir[File.join(@project_dir, pattern)]
                when Array
                  pattern.inject([]) {|t, ep| t + pattern_filter_lab.call(ep)}
                else
                  raise('Error pattern type')
                end

          return ret unless exclude_pattern

          case exclude_pattern
          when String
            ret -= Dir[File.join(@project_dir, exclude_pattern)]
          when Array
            ret -= exclude_pattern.inject([]) {|t, ep| t + Dir[File.join(@project_dir, ep)]}
          else
            raise('Error exclude_pattern type')
          end

          ret
        end

        # 按照指定资源属性排除要求排除相应的spec路径
        # @param [Array<String>] spec_paths spec的执行路径列表
        # @param [Array<String>] res_exclude_patterns,
        #   每一个元素的格式是这样:
        #     res_type: res_attr1==2,res_attr3>=4
        #   或者
        #     type==res_type,res_attr1==2,res_attr3>=4
        # @return [Array<String>] 按照`res_exclude_pattern` 剔除后的 `spec_paths`
        def exclude_spec_by_resource(spec_paths, res_exclude_patterns = [])
          return spec_paths if res_exclude_patterns.empty?

          spec_paths.reject do |spec_path|
            spec_info = get_spec_path_info(spec_path)
            profile_lines = parse_spec_profile_lines(spec_info[:file])
            res_exclude_patterns.any? do |exclude_pattern|
              res_attrs = if exclude_pattern =~ /^\w+:\s*.+/
                            type, attrs = exclude_pattern.split(/:\s*/, 2)
                            "type==#{type}," + attrs
                          else
                            exclude_pattern
                          end
              res_attrs = res_attrs.split(',')
              profile_lines.any? {|line| res_attrs.all? {|attr| line =~ /\b#{attr}\b/}}
            end
          end
        end
      end
    end
  end
end