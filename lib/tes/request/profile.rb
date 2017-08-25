require_relative 'ask'

module Tes
  module Request
    class Profile
      include Comparable

      REG_LOCK_HEADER = /^(@|$)\s*\|+\s*/
      REG_POINT_ASK = /^\*(\d+):/
      REG_REFER_ASK = /^&(\d+)\./
      REG_POINT_ASK_GREEDY = /^\[\*(\d+)\]:/
      REG_REFER_ASK_GREEDY = /^\[&(\d+)\]\./

      # 深度解析环境要求
      # @param [Array<String>] profile_lines 测试环境要求语句列表
      def initialize(profile_lines=[])
        @data = []

        # 不因申明顺序不一致性等其他差异而误判环境要求的一致性
        point_asks = {}
        profile_lines.each do |line|
          lock_type = (line =~ REG_LOCK_HEADER and line =~ /^$/) ? :share : :lock

          case line
            when REG_POINT_ASK
              mt = line.match(REG_POINT_ASK)
              ask = Ask.new line.sub(REG_POINT_ASK, '')
              ask.lock_type = lock_type
              point_asks[mt[1]] = ask
            when REG_POINT_ASK_GREEDY
              mt = line.match(REG_POINT_ASK_GREEDY)
              ask = Ask.new line.sub(REG_POINT_ASK_GREEDY, '')
              ask.greedy= true
              ask.lock_type = lock_type
              point_asks[mt[1]] = ask
            when REG_REFER_ASK
              mt= line.match(REG_REFER_ASK)
              src_ask = point_asks[mt[1]]
              ref_exp = Expression.new line.sub(REG_REFER_ASK, '')
              src_ask.reference << ref_exp
            when REG_REFER_ASK_GREEDY
              mt= line.match(REG_REFER_ASK_GREEDY)
              src_ask = point_asks[mt[1]]
              ref_exp = Expression.new line.sub(REG_REFER_ASK_GREEDY, '')
              src_ask.reference << ref_exp
            else
              ask = Ask.new(line)
              ask.lock_type =lock_type
              @data << ask
          end
        end

        @data += point_asks.values
      end

      attr_reader :data

      def <=>(other)
        all_self_hash = self.data.group_by {|e| e.to_s}
        all_self_hash_keys = Set.new all_self_hash.keys
        all_other_hash = other.data.group_by {|e| e.to_s}
        all_other_hash_keys = Set.new all_other_hash.keys

        # 如果相等或者可比较则直接返回(只在相等的时候有效)
        return 0 if all_self_hash == all_other_hash

        hash1 = Hash[all_self_hash_keys.to_a.map {|e| [e, true]}]
        all_other_hash_keys.to_a.each do |k|
          hash1.include?(k)
        end

        if all_self_hash_keys == all_other_hash_keys
          compare_when_keys_same(all_self_hash, all_other_hash)
        elsif all_self_hash_keys < all_other_hash_keys
          compare_when_keys_subset(all_self_hash, all_other_hash)
        elsif all_self_hash_keys > all_other_hash_keys
          ret = compare_when_keys_subset(all_other_hash, all_self_hash)
          ret ? 0 - ret : ret
        else
          nil
        end
      end


      def +(other)
        ret = self.<=>(other)
        case ret
          when 0, 1
            self
          when -1
            other
          else
            merge(other)
        end
      end

      def merge_able?(other)
        self.+(other)
        true
      rescue RuntimeError
        false
      end

      # 向资源池环境中申请资源,但并不进行锁定,只是有礼貌的进行问询式申请
      #   真需要使用资源,需要在其返回列表后向服务器申请锁定这些资源列表
      # @param [Hash<String,Hash>] pool 所有空闲可用的资源池
      def request(pool)
        get_candidates_lab = ->(ask, answer_cache) do
          pool.keys.select {|k| !answer_cache.include?(k) && ask.match?(pool[k])}
        end

        answers_flat = []
        answers = @data.map do |ask|
          candidates = get_candidates_lab.call(ask, answers_flat)
          unless candidates.size > 0
            nil
          else
            if ask.greedy
              answers_flat += candidates
              unless ask.reference.size > 0
                candidates
              else
                candidates.map do |candidate|
                  refs = ask.reference.inject([]) do |t, r|
                    ret = pool[candidate].get_by_chain(r.data[:left_exp])
                    ret.is_a?(Array) ? (t + ret) : (t << ret)
                  end
                  answers_flat += refs
                  [candidate, refs]
                end
              end
            else
              candidate = candidates.first
              answers_flat << candidate
              unless ask.reference.size > 0
                candidate
              else
                refs = ask.reference.inject([]) do |t, r|
                  ret = pool[candidate].get_by_chain(r.data[:left_exp])
                  ret.is_a?(Array) ? (t + ret) : (t << ret)
                end
                answers_flat += refs
                [candidate, refs]
              end
            end
          end
        end

        answers
      end

      def to_s(split="\n")
        ret = []
        point = 0
        @data.each do |ask|
          if ask.reference and ask.reference.size > 0
            point_ask = ask
            refer_asks = ask.reference
            point += 1
            ret << ("*#{point}:" + point_ask.to_s)
            refer_asks.each do |r_ask|
              ret << ("&#{point}." + r_ask.to_s)
            end
          else
            ret << ask.to_s
          end
        end
        ret.join(split)
      end

      private
      def compare_when_keys_same(hash_self, hash_other)
        size_compare_results = hash_self.keys.map {|k| hash_self[k].size <=> hash_other[k].size}
        if size_compare_results.all? {|v| v && v <= 0}
          size_compare_results.any? {|v| v == -1} ? -1 : 0
        elsif size_compare_results.all? {|v| v && v >= 0}
          size_compare_results.any? {|v| v == 1} ? 1 : 0
        else
          nil
        end
      end

      def compare_when_keys_subset(hash_self, hash_other)
        subset_keys = hash_self.keys
        hash_other_subset = subset_keys.inject({}) {|t, k| t.merge(k => hash_other[k])}
        ret = compare_when_keys_same(hash_self, hash_other_subset)
        ret && (ret <= 0 ? -1 : nil)
      end

      # @return [Hash<Object,Array<Object>>]
      def merge_when_keys_diff!(hash_self, hash_other)
        merge_able_lab = ->(to, from) do
          from.keys.all? do |f_ask|
            if to.any? {|k, _| f_ask <=> k}
              true
            else
              if f_ask.data['type']
                to.keys.none? {|e| e.data['type'] && e.data['type'] and e.data['type'] == f_ask.data['type']}
              else
                true
              end
            end
          end
        end
        merge_lab = ->(to, from) do
          # 现将内容全部拼起来,然后合并资源
          ret_hash = {}
          to.each {|ask, ask_dup_list| ret_hash[ask] = ask_dup_list}
          from.each do |ask, ask_dup_list|
            # 是否有相同要求的资源要求
            if ret_hash[ask]
              unless ret_hash[ask].size >= ask_dup_list
                ret_hash[ask] += ask_dup_list[ret_hash[ask].size..-1]
              end
            else
              # 没有

              # 是否总结果中有可合并的资源请求
              merge_able_ask = ret_hash.keys.find {|a| a <=> ask}
              if merge_able_ask
                if merge_able_ask >= ask
                  if ret_hash[merge_able_ask].size < ask_dup_list.size
                    ret_hash[merge_able_ask] += ask_dup_list[ret_hash[merge_able_ask].size..-1]
                  end
                else
                  if ret_hash[merge_able_ask].size <= ask_dup_list.size
                    ret_hash.delete(merge_able_ask)
                    ret_hash[ask] = ask_dup_list
                  else
                    ret_hash[ask] = ask_dup_list
                    ret_hash[merge_able_ask].pop(ask_dup_list.size)
                  end
                end
              else
                ret_hash[ask] = ask_dup_list
              end
            end
          end

          ret_hash
        end

        if merge_able_lab.call(hash_self, hash_other)
          merge_lab.call(hash_self, hash_other)
        elsif merge_able_lab.call(hash_other, hash_self)
          merge_lab.call(hash_other, hash_self)
        else
          raise('冲突较大,不能合并')
        end
      end

      def merge(other)
        all_self_hash = self.data.group_by {|e| e.to_s}
        all_self_hash = Hash[all_self_hash.map {|k, v| [Ask.new(k), v]}]
        all_other_hash = other.data.group_by {|e| e.to_s}
        all_other_hash = Hash[all_other_hash.map {|k, v| [Ask.new(k), v]}]
        all_self_hash_keys = Set.new all_self_hash.keys
        all_other_hash_keys = Set.new all_other_hash.keys

        merge_when_same_keys_lab = ->(keys) do
          keys.inject({}) do |t, k|
            if all_self_hash[k].size >= all_other_hash[k].size
              t.merge k => all_self_hash[k]
            else
              t.merge k => all_other_hash[k]
            end
          end
        end

        result = if all_self_hash_keys == all_other_hash_keys
                   merge_when_same_keys_lab.call(all_self_hash_keys)
                 elsif all_self_hash_keys < all_other_hash_keys
                   ret = merge_when_same_keys_lab.call(all_self_hash_keys)
                   all_other_hash.merge(ret)
                 elsif all_self_hash_keys > all_other_hash_keys
                   ret = merge_when_same_keys_lab.call(all_other_hash_keys)
                   all_self_hash.merge(ret)
                 else
                   merge_when_keys_diff!(all_self_hash, all_other_hash)
                 end
        new_instance = self.class.new([])


        result.values.flatten.each {|v| new_instance.data.push v}
        new_instance
      end
    end
  end
end