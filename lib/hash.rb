class Hash
  # Magic predicates. For instance:
  #
  #   options.force?                  # => !!options['force']
  #   options.shebang                 # => "/usr/lib/local/ruby"
  #   options.test_framework?(:rspec) # => options[:test_framework] == :rspec
  #
  def method_missing(method, *args, &block)
    judge_mt = method.to_s.match(/^(\w+)\?$/)

    return (self[method] || self[method.to_s]) unless judge_mt
    value = self[judge_mt[1]] || self[judge_mt[1].to_sym]
    args.empty? ? !!value : (value == args.first)
  end

  # 串联获取内部嵌套hash值
  # @param [String] chain_str 嵌套取值表达式
  # @return [Object]
  def get_by_chain(chain_str)
    chains = chain_str.split('.')
    chains.keep_if { |k| k =~ /.+/ }
    chains.inject(self) { |t, p| t && t.send(p) }
  end
end