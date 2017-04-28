require_relative '../../../../lib/tes/request/rspec/profile_parser'

describe Tes::Request::RSpec::ProfileParser do
  before(:all) { @project_dir = File.join(RSpec::Root, '.data') }

  # @param [Array<String>] data_files 文件路径列表(相对与`@project_dir`)
  def parser(data_files)
    real_file_paths = data_files.map { |f| File.join(@project_dir, f) }
    Tes::Request::RSpec::ProfileParser.new real_file_paths
  end

  context '#parse_profiles!' do
    def test_h_get_profiles(files)
      p = parser(files)
      p.parse_profiles!
      p.profiles
    end

    it 'common file paths' do
      files = %w|spec/a/2/test1_spec.rb
                 spec/b/1_spec.rb|
      profiles = test_h_get_profiles(files)
      expect(profiles.size).to eq 2
      profiles.each { |p| expect(p).not_to include(:ids, :locations) }
    end
    it 'file paths with locations' do
      files = %w|spec/a/2/test1_spec.rb:13
                 spec/b/1_spec.rb:10|
      profiles = test_h_get_profiles(files)
      expect(profiles.size).to eq 2
      profiles.each do |p|
        expect(p).to include(:locations)
        expect(p[:locations]).to be_a(Array)
        p[:locations].each { |line| expect(line).to be_a(Fixnum) }
        expect(p).not_to include(:ids)
      end
    end
    context 'file paths with ids' do
      it 'have inherits' do
        files = %w|spec/a/2/test1_spec.rb[1:1]
                   spec/a/1_spec.rb[1:2:1]
                   spec/a/1_spec.rb[1:2]|
        profiles = test_h_get_profiles(files)
        expect(profiles.size).to eq 2
        profiles.each do |p|
          expect(p).not_to include(:locations)
          expect(p).to include(:ids)
          expect(p[:ids]).to be_a(Array)
        end
        expect(profiles).not_to include(
                                    include(
                                        :file => end_with('spec/a/1_spec.rb'),
                                        :ids => include('1:2:1')
                                    )
                                )
      end
      it 'no inherits' do
        files = %w|spec/a/2/test1_spec.rb[1:1]
                   spec/a/1_spec.rb[1:2:1]
                   spec/a/1_spec.rb[1:2:2]|
        profiles = test_h_get_profiles(files)
        expect(profiles.size).to eq 2
        profiles.each do |p|
          expect(p).not_to include(:locations)
          expect(p).to include(:ids)
          expect(p[:ids]).to be_a(Array)
        end

        expect(profiles).to include(
                                    include(
                                        :file => end_with('spec/a/1_spec.rb'),
                                        :ids => contain_exactly('1:2:1', '1:2:2')
                                    )
                                )
      end
    end
  end
end
