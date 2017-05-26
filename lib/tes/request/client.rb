require 'json'

module Tes
  module Request
    class Client
      # Construction
      # @param [HTTPClient] driver the http session instance
      def initialize(driver)
        @driver = driver
        http_methods = [:get, :post, :put, :delete, :head]
        http_methods.each do |m|
          unless @driver.respond_to?(m)
            fail_msg = "invalid arg [driver]: not support method: #{m}"
            raise(ArgumentError, fail_msg)
          end
        end
      end

      attr_reader :driver

      # @param [String] user
      # @param [Array<String>] asks
      # @return [Hash]
      def request_env(user, asks)
        res = @driver.post('/env', body: {user: user, ask: asks.join("\n")}.to_json)
        ret = parse_res res

        if ret.is_a?(Hash) and
            ret[:success] and
            ret[:data].is_a?(Hash) and
            ret[:data][:res].is_a?(Hash)
          res_hash = ret[:data][:res]
          res_hash.keys.each { |k| res_hash[k.to_s] = res_hash.delete(k) }
          ret[:data][:res] = res_hash
        end

        ret
      end

      # @param [String] id resource id
      # @param [String] user lock/using username
      # @param [1,0] lock need lock? `false` == shared using
      def request_res(id, user, lock=1)
        res = @driver.post("/res/#{id}/lock", body: {user: user, lock: lock})
        parse_res res
      end

      def release_res(id, user)
        res = @driver.post("/res/#{id}/release", body: {user: user})
        parse_res res
      end

      def release_all_res(user)
        res_list = parse_res @driver.get('/res')
        res_list[:data].select { |_k, c| c[:users] && c[:users].include?(user) }.each do |id, _c|
          release_res(id, user)
        end
      end

      private
      def parse_res(res)
        unless res.ok? or res.redirect?
          fail_msg = "[#{res.status}]:#{res.body}"
          raise(fail_msg)
        else
          res_body = res.body
          if res.http_header['Content-Type'].any? { |h| h =~ /application\/json/i }
            res_body = JSON.parse(res_body, :symbolize_names => true) rescue res_body
          end
          res_body
        end
      end
    end
  end
end