module Tes
  module Request
    class Expression
      include Comparable

      REG_EXP_CHAIN = /^(!)?([0-9A-Za-z_.]+)(\?|=|>=|<=|<|>)?(-?[\w]+(\.[\d]+)?)?/

      # @param [String] exp_str 表达式字符串
      def initialize(exp_str)
        mt = exp_str.match(REG_EXP_CHAIN)
        raise(ArgumentError, "非法的表达式片段:\t#{exp_str}") unless mt

        @data = {}
        @data[:revert] = true if mt[1]
        @data[:left_exp] = mt[2]
        if mt[3]
          @data[:op] = mt[3]
          if mt[4]
            @data[:expect_val] = mt[4]
            if @data[:expect_val] =~ /^-?\d+(\.[\d]+)?/
              @data[:expect_val] = mt[5] ? @data[:expect_val].to_f : @data[:expect_val].to_i
            end
          end
        end
      end

      attr_reader :data

      # 计算数据是否满足表达式(深度解析后)
      # @param [Object] data
      # @return [true,false]
      def match?(data)
        op = @data[:op]
        unless data.respond_to?(:get_by_chain)
          raise(ArgumentError, 'data arg should be respond to :get_by_chain')
        else
          ret = if !op
                  data.get_by_chain @data[:left_exp]
                elsif op == '?'
                  chain_data = data.get_by_chain(@data[:left_exp])
                  case chain_data
                    when 'off', 'down', 'disable', '0', '', 0
                      false
                    else
                      chain_data
                  end
                else
                  op = '==' if op == '='
                  expect_val = @data[:expect_val]
                  data.get_by_chain(@data[:left_exp]).send(op, expect_val)
                end
          @data[:revert] ? !ret : ret
        end
      end

      def <=>(other)
        return 0 if @data == other.data
        return nil if @data[:revert] != other.data[:revert] or @data[:left_exp] != other.data[:left_exp]

        if @data[:op] == other.data[:op]
          case @data[:op]
            when '=', '=='
              (@data[:expect_val] == other.data[:expect_val]) ? 0 : nil
            when '>', '>='
              @data[:expect_val] <=> other.data[:expect_val]
            when '<', '<='
              other.data[:expect_val] <=> @data[:expect_val]
            when '?', nil
              0
            else
              raise("内部错误:出现了不支持的表达式操作符号:#{@data[:op]}")
          end
        else
          case [@data[:op], other.data[:op]]
            when %w(< <=)
              ret = other.data[:expect_val] <=> @data[:expect_val]
              ret == 0 ? 1 : ret
            when %w(< =)
              @data[:expect_val] > other.data[:expect_val] ? -1 : nil
            when %w(= >)
              @data[:expect_val] > other.data[:expect_val] ? 1 : nil
            when %w(= >=)
              @data[:expect_val] >= other.data[:expect_val] ? 1 : nil
            when %w(= <)
              @data[:expect_val] < other.data[:expect_val] ? 1 : nil
            when %w(= <=)
              @data[:expect_val] <= other.data[:expect_val] ? 1 : nil
            when %w(> >=)
              ret = @data[:expect_val] <=> other.data[:expect_val]
              ret == 0 ? 1 : ret
            when %w(> =)
              @data[:expect_val] < other.data[:expect_val] ? -1 : nil
            when %w(>= =)
              @data[:expect_val] <= other.data[:expect_val] ? -1 : nil
            when %w(>= >)
              ret = @data[:expect_val] <=> other.data[:expect_val]
              ret == 0 ? -1 : ret
            when %w(<= =)
              @data[:expect_val] <= other.data[:expect_val] ? 1 : nil
            when %w(<= <)
              ret = other.data[:expect_val] <=> @data[:expect_val]
              ret == 0 ? -1 : ret
            else
              nil
          end
        end
      end

      def to_s
        ret = [:left_exp, :op, :expect_val].map { |k| @data[k] }.join
        ret = '!' + ret if @data[:revert]
        ret
      end
    end
  end
end