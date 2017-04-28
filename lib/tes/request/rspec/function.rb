module Tes
  module Request
    module RSpec
      module Function
        # 对spec路径获取相关信息(行号或者序号等信息)
        # @param [String] spec_path
        # @param [Hash]
        def get_spec_path_info(spec_path)
          ids_reg = /\[([\d:,]+)\]$/
          locations_reg = /:([\d:]+)$/
          if spec_path =~ ids_reg
            ids = spec_path.match(ids_reg)[1].split(',')
            file_path = spec_path.sub(ids_reg, '')
            {file: file_path, ids: ids}
          elsif spec_path =~ locations_reg
            locations = spec_path.match(locations_reg)[1].split(':').map(&:to_i)
            file_path = spec_path.sub(locations_reg, '')
            {file: file_path, locations: locations}
          else
            {file: spec_path}
          end
        end

        # 解析spec文件的测试环境要求文本内容
        # @return [Array<String>]
        def parse_spec_profile_lines(spec_file)
          ret = nil
          File.open(spec_file, 'r') do |f|
            f.each_line do |l|
              case l
                when /^\s*#\s*@env\s+begin\s*$/
                  ret = []
                when /^\s*#\s*@end/
                  break
                when /^\s*#/
                  ret << l.sub(/^\s*#\s*/, '') if ret
                else
                  #nothing
              end
            end
          end

          ret && ret.map(&:strip).map { |l| l.split(/\s*;\s*/) }.flatten
        end
      end
    end
  end
end