require_relative '../../../../lib/tes/request/rspec/function'

describe Tes::Request::RSpec::Function do
  class MockObject
    include Tes::Request::RSpec::Function
  end
  subject { MockObject.new }
  let(:file_path) { 'spec/xxx/abcdefg_spec.rb' }
  context '#get_spec_path_info' do
    it 'common file path' do
      path = file_path
      expect(subject.get_spec_path_info(path)).to eq(file: file_path)
    end

    it 'path with single line' do
      path = "#{file_path}:123"
      expect(subject.get_spec_path_info(path)).to eq(file: file_path, locations: [123])
    end
    it 'path with multi line' do
      path = "#{file_path}:123:456:789"
      expect(subject.get_spec_path_info(path)).to eq(file: file_path, locations: [123, 456, 789])
    end
    it 'path with single id path' do
      path = "#{file_path}[1:2:3]"
      expect(subject.get_spec_path_info(path)).to eq(file: file_path, ids: ['1:2:3'])
    end
    it 'path with multi id path' do
      path = "#{file_path}[1:2:3,4:5:6]"
      expect(subject.get_spec_path_info(path)).to eq(file: file_path, ids: ['1:2:3', '4:5:6'])
    end
  end
end