require 'set'
require_relative 'expression'

module Tes
  module Request
    class Ask
      include Comparable

      # @param [String] ask_str 单个资源的请求要求字符串
      def initialize(ask_str)
        snippets = ask_str.strip.sub(/^\*\d+:/, '').sub(/^&\d+\./, '').split(/\s*,\s*/)
        expressions = snippets.map { |s| Expression.new(s) }
        @data = expressions.inject({}) { |t, e| t.merge(e.data[:left_exp] => e) }
        # @reference 是表达式列表
        @reference = []
        @greedy = false
      end

      attr_reader :data, :reference
      attr_accessor :greedy

      # 计算数据是否满足要求
      # @param [Object] data
      def match?(data)
        @data.all? { |_n, exp| exp.match?(data) }
      end

      def <=>(other)
        exp_compare_lab = -> (a, b) do
          if a.nil? and b.nil?
            0
          elsif a.nil?
            -1
          elsif b.nil?
            1
          else
            a <=> b
          end
        end

        ret = if @data == other.data
                0
              elsif self.data > other.data
                1
              elsif self.data < other.data
                -1
              else
                a_to_b_results = @data.map { |n, e| exp_compare_lab.call(e, other.data[n]) }
                if a_to_b_results.all? { |ret| ret and ret <= 0 }
                  -1
                elsif a_to_b_results.all? { |ret| ret and ret >= 0 }
                  # 这时必须要求other的表达式全部能被self覆盖.
                  (other.data.keys - @data.keys).size > 0 ? nil : 1
                else
                  nil
                end
              end
        case [greedy, other.greedy]
          when [true, false]
            return ret unless ret
            ret >=0 ? 1 : nil
          when [false, true]
            return ret unless ret
            ret <=0 ? -1 : nil
          else
            ret
        end
      end

      # 相对other要求多的和严格的
      # @return [Ask]
      def -(other)
        diff_data = @data.reject do |n, e|
          o_e = other.data[n]
          o_e && e <= o_e
        end

        diff_ask = self.new('')
        diff_ask.data.merge!(diff_data)
        diff_ask
      end

      # 合并叠加对资源的请求
      # @return [Ask]
      def +(other)
        if self == other
          self
        elsif self >=other
          self
        elsif self <other
          other
        else
          raise('不能合并叠加') unless merge_able?(other)

          self_gt_other = self.-(other)
          other_gt_self = other.-(self)

          ask1 = self.new('')
          ask2 = self.new('')
          ask1.data.merge!(self.data)
          ask1.data.merge!(other_gt_self)
          ask2.data.merge!(other.data)
          ask2.data.merge!(self_gt_other)
          ask1 >= ask2 ? ask1 : ask2
        end
      end

      def merge_able?(other)
        if self.<=> other
          true
        else
          self_gt_other = self.-(other)
          other_gt_self = other.-(self)
          conflict_exp_keys = self_gt_other.data.keys & other_gt_self.data.keys
          conflict_exp_keys.empty?
        end
      rescue ArgumentError
        false
      end

      def to_s
        @data.values.map(&:to_s).join(',')
      end
    end
  end
end