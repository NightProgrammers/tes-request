require 'json'
require 'httpclient'
require 'timeout'

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
        res = @driver.post('env', body: {user: user, ask: asks.join("\n")}.to_json)
        ret = parse_res res

        if ret.is_a?(Hash) and
            ret[:success] and
            ret[:data].is_a?(Hash) and
            ret[:data][:res].is_a?(Hash)
          res_hash = ret[:data][:res]
          res_hash.keys.each {|k| res_hash[k.to_s] = res_hash.delete(k)}
          ret[:data][:res] = res_hash
        end

        ret
      end

      # @param [String] id resource id
      # @param [String] user lock/using username
      # @param [1,0] lock need lock? `false` == shared using
      def request_res(id, user, lock = 1)
        res = @driver.post("res/#{id}/lock", body: {user: user, lock: lock})
        parse_res res
      end

      def release_res(id, user)
        res = @driver.post("res/#{id}/release", body: {user: user})
        parse_res res
      end

      def release_all_res(user)
        res_list = parse_res @driver.get('res')
        res_list[:data].select {|_k, c| c[:users] && c[:users].include?(user)}.each do |id, _c|
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
          if res.http_header['Content-Type'].any? {|h| h =~ /application\/json/i}
            res_body = JSON.parse(res_body, :symbolize_names => true) rescue res_body
          end
          res_body
        end
      end
    end

    class ClientBin
      def self.exit_usage(program, exit_code = 2)
        puts <<EOF
Usage:
    % #{program} {TesWebUrl} {User} request_res  {ResourceId}  [1|0]                       # Request Specified Resource
    % #{program} {TesWebUrl} {User} release_res  {ResourceId}                              # Release Specified Resource
    % #{program} {TesWebUrl} {User} request_pool {PoolAskFile} {SaveFile} [TimeoutSeconds] # Request Env Pool 
    % #{program} {TesWebUrl} {User} release_pool [PoolFile]                                # Release Env Pool
EOF
        exit exit_code
      end

      def initialize(tes_url, user)
        driver = HTTPClient.new(base_url: tes_url)
        driver.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
        @client = Client.new(driver)
        @user = user
      end

      # Cli runner method
      # @param [String] op_type
      # @param [Array<String>] op_args
      def run(op_type, op_args, program = __FILE__)
        assert_args(op_type, op_args) ? send(op_type, *op_args) : self.exit_usage(program, 2)
      end

      private

      def assert_args(op_type, op_args)
        case op_type
          when 'request_res'
            op_args.size.between?(1, 2)
          when 'release_res'
            op_args.size == 1
          when 'request_pool'
            op_args.size.between?(2, 3)
          when 'release_pool'
            op_args.size.between?(0, 1)
          else
            false
        end
      end

      def request_res(res_id, lock = 0)
        ret = @client.request_res(res_id, @user, lock)

        msg_suffix = "Request resource:(id: #{res_id}, user: #{@user}, lock: #{lock})."
        ret[:success] ? puts("[ OK ] #{msg_suffix}") : warn("[Fail] #{msg_suffix}")

        ret[:success]
      end

      def release_res(res_id)
        ret = @client.release_res(res_id, @user)

        msg_suffix = "Release resource:(id: #{res_id}, user: #{@user})."
        ret[:success] ? puts("[ OK ] #{msg_suffix}") : warn("[Fail] #{msg_suffix}")

        ret[:success]
      end

      def release_pool(saved_env_file = nil)
        if saved_env_file and File.exists?(saved_env_file)
          env_pool_info = YAML.load_file(saved_env_file)
          locks = env_pool_info[:lockes]
          locks.each {|lock| @client.release_res(lock, @user)} if locks
          puts "[Info] Release env done(user: #{@user}, file: #{saved_env_file})."
        else
          @client.release_all_res(@user)
          puts "[Info] Release env done(user: #{@user})."
        end

        true
      end

      # request env pool
      def request_pool(profile_file, save_file, timeout_secs = 0)
        File.exists?(profile_file) || raise(ArgumentError, "[ ER ] File not found:#{profile_file}")

        asks = File.readlines(profile_file).map!(&:strip).compact

        Timeout.timeout(timeout_secs && timeout_secs.to_i) do
          print '[Info] Request env...'

          ret = {}
          until ret[:success]
            print '.'
            ret = @client.request_env(@user, asks)
            sleep 5 unless ret[:success]
          end

          # request successfully
          puts 'successfully!'
          File.open(save_file, 'w') do |f|
            f.write ret[:data].to_yaml
            puts '[ OK ] Request env done, saved in: ' + save_file
          end
        end

        true
      end
    end
  end
end