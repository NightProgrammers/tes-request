require_relative '../profile'
require_relative 'function'

# 分析rspec profile信息
module Tes
  module Request
    module RSpec
      class ProfileParser
        def initialize(spec_paths=[])
          @spec_paths = spec_paths
        end

        attr_reader :profiles

        def <<(spec_path)
          @spec_paths << spec_path
        end

        def parse_profiles!
          profile_map = {}

          @spec_paths.each do |s_p|
            spec_info = parse_spec(s_p)

            # 如果相同文件则进行合并
            if profile_map.key?(spec_info[:file])
              profile_map[spec_info[:file]] = merge_spec_info(profile_map[spec_info[:file]], spec_info)
            else
              profile_map[spec_info[:file]] = spec_info
            end
          end

          # 对存在的包含关系的ids尝试合并
          profile_map.each do |_f, info|
            info[:ids] = merge_spec_ids(info[:ids]) if info[:ids]
            info[:locations].sort! if info[:locations]
          end
          @profiles = profile_map.values
        end

        private

        include Function

        # 合并2个spec info数据结构
        # @param [Hash] a
        # @param [Hash] b
        # @return [Hash] merge result, same struct with `a` or `b`
        def merge_spec_info(a, b)
          raise('不支持合并不同spec文件的信息') unless a[:file] == b[:file]

          compare_keys = [:ids, :locations]
          a_compare_keys = a.keys.select { |k| compare_keys.include?(k) }.sort
          b_compare_keys = b.keys.select { |k| compare_keys.include?(k) }.sort

          case [a_compare_keys, b_compare_keys]
            # 都有ids的情况
            when [[:ids], [:ids]], [[:ids, :locations], [:ids]]
              a.merge(ids: (a[:ids] + b[:ids]).uniq)
            when [[:ids], [:ids, :locations]]
              b.merge(ids: (a[:ids] + b[:ids]).uniq)

            # 都有locations的情况
            when [[:locations], [:locations]], [[:ids, :locations], [:locations]]
              a.merge(locations: (a[:locations] + b[:locations]).uniq)
            when [[:locations], [:ids, :locations]]
              a.merge(locations: (b[:locations] + a[:locations]).uniq)

            # 都有ids和locations
            when [[:ids, :locations], [:ids, :locations]]
              a.merge(
                  ids: (a[:ids] + b[:ids]).uniq,
                  locations: (a[:locations] + b[:locations]).uniq
              )

            # 互补
            when [[:ids], [:locations]], [[:locations], [:ids]]
              a.merge b
            else
              # 只剩下 a_compare_keys 为空 或者 b_compare_keys为空的情况
              a_compare_keys.empty? ? a : b
          end
        end

        # @param [Array<String>] ids
        def merge_spec_ids(ids)
          ids.sort.inject([]) do |t, id|
            id_is_covered = (t.last && id.index(t.last) == 0)
            id_is_covered ? t : t.push(id)
          end
        end

        # @param [Array<String>] str_array, 每个元素的格式可以是这样:
        #   - `--xxx`
        #   - `-yy`
        #   - `-x vvv`
        #   - `--zz vvv`
        # @return [Hash<Symbol, Object>]
        def parse_distribute_profile(str_array)
          str_array.inject({}) do |d_p, str|
            args = str.scan(/-+[^-]+\b/).map { |arg| arg.sub(/^-+/, '').split(/\s+/) }
            d_p_phrase = args.inject({}) { |h, arg| h.merge(arg[0].to_sym => arg[1] || true) }
            d_p.merge d_p_phrase
          end
        end

        # 解析指定路径spec的执行解析
        # @param [String] spec_path 当前支持3种格式
        #   - 一种是普通的文件路径格式
        #   - 一种是文件格式基础上增加行数指定的格式,单个或者多个,单个格式 `:123`,多个直接拼接起来
        #   - 一种是文件格式基础上增加用例层次路径的格式,单个或者多个,单个格式`[1:2:3]`,多个在括号内用逗号间隔:`[1:2:3,2:3:4]`
        # @return [Hash] include keys: `:file`, `:profile`, `:distribute`(optional)
        def parse_spec(spec_path)
          spec_info = get_spec_path_info spec_path

          profile_lines = parse_spec_profile_lines(spec_info[:file])
          raise("#{spec_info[:file]} 没有ci profile配置,请确认!") unless profile_lines and profile_lines.size > 0

          distribute_lines = profile_lines.
              select { |l| l =~ /^\s*@distribute\s+/ }.
              map { |l| l.sub(/^\s*@distribute\s+/, '') }
          profile_lines.reject! { |l| l =~ /^\s*@distribute\s+/ }

          spec_info.merge(
              profile: Profile.new(profile_lines),
              distribute: parse_distribute_profile(distribute_lines)
          )
        end
      end
    end
  end
end