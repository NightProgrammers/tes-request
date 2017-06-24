require_relative '../../../../lib/tes/request/rspec/distribute'
require 'fileutils'

describe Tes::Request::RSpec::Distribute do
  let(:project_dir) { File.join(RSpec::Root, '.data') }
  subject(:project_dis) { Tes::Request::RSpec::Distribute.new(project_dir) }

  context '#spec_files' do
    it 'one_pattern' do
      files = subject.instance_exec { spec_files(RSpec.current_example.description) }
      expect(files).to contain_exactly(
                           end_with('spec/a/2/test1_spec.rb'),
                           end_with('spec/a/1_spec.rb')
                       )
    end
    it 'many_patterns' do
      files = subject.instance_exec { spec_files(RSpec.current_example.description) }
      expect(files).to contain_exactly(
                           end_with('spec/a/2/test1_spec.rb'),
                           end_with('spec/a/1_spec.rb'),
                           end_with('spec/b/1_spec.rb'),
                           end_with('spec/b/broken_test2_spec.rb'),
                           end_with('spec/b/exclude_test1_spec.rb'),
                           end_with('spec/h1_spec.rb'),
                           end_with('spec/h2_spec.rb')
                       )
    end
    it 'with_one_exclude_pattern' do
      files = subject.instance_exec { spec_files(RSpec.current_example.description) }
      expect(files).to contain_exactly(
                           end_with('spec/a/2/test1_spec.rb'),
                           end_with('spec/a/1_spec.rb'),
                           end_with('spec/b/1_spec.rb'),
                           end_with('spec/b/broken_test2_spec.rb')
                       )
    end
    it 'with_many_exclude_pattern' do
      files = subject.instance_exec { spec_files(RSpec.current_example.description) }
      expect(files).to contain_exactly(
                           end_with('spec/a/2/test1_spec.rb'),
                           end_with('spec/a/1_spec.rb'),
                           end_with('spec/b/1_spec.rb')
                       )
    end
    it 'pattern_with_locations' do
      files = subject.instance_exec { spec_files(RSpec.current_example.description) }
      expect(files).to contain_exactly(
                           end_with('spec/a/2/test1_spec.rb:13'),
                           end_with('spec/a/1_spec.rb:16'),
                           end_with('spec/a/1_spec.rb:13'),
                           end_with('spec/b/1_spec.rb'),
                           end_with('spec/b/broken_test2_spec.rb'),
                           end_with('spec/b/exclude_test1_spec.rb')
                       )
    end
    it 'pattern_with_ids_no_inherit' do
      files = subject.instance_exec { spec_files(RSpec.current_example.description) }
      expect(files).to contain_exactly(
                           end_with('spec/a/2/test1_spec.rb[1:1:1:1]'),
                           end_with('spec/a/1_spec.rb[1:1:2]'),
                           end_with('spec/a/1_spec.rb[1:1:1]'),
                           end_with('spec/b/1_spec.rb'),
                           end_with('spec/b/broken_test2_spec.rb'),
                           end_with('spec/b/exclude_test1_spec.rb')
                       )
    end
    it 'pattern_dir_include_disabled' do
      files = subject.instance_exec { spec_files(RSpec.current_example.description) }
      expect(files).to contain_exactly(end_with('spec/include_disabled/1_spec.rb'))
    end
    it 'exclude_res_with_special_attributes' do
      begin
        file_name = File.join(project_dir, Tes::Request::RSpec::Distribute::EXCLUDE_CLUSTER_RES_PATTERN_PROFILE)
        ['yyy:label.label_x=a', 'type=yyy,label.label_x=a'].each do |test_data|
          File.open(file_name, 'w') { |f| f.write test_data }
          files = subject.instance_exec { spec_files('many_patterns') }
          expect(files).not_to include(include('spec/a/2/test1_spec.rb'),
                                       include('spec/a/1_spec.rb'))
          files = subject.instance_exec { spec_files('pattern_with_locations') }
          expect(files).not_to include(include('spec/a/2/test1_spec.rb'),
                                       include('spec/a/1_spec.rb'))
          files = subject.instance_exec { spec_files('pattern_with_ids_no_inherit') }
          expect(files).not_to include(include('spec/a/2/test1_spec.rb'),
                                       include('spec/a/1_spec.rb'))
          files = subject.instance_exec { spec_files('pattern_with_ids_inherit') }
          expect(files).not_to include(include('spec/a/2/test1_spec.rb'),
                                       include('spec/a/1_spec.rb'))
        end
      ensure
        File.delete(file_name)
      end
    end
  end
  context '#distribute_jobs' do
    it 'one_pattern' do
      jobs = project_dis.distribute_jobs(RSpec.current_example.description, 1)
      expect(jobs.size).to eq 1
      expect(jobs.first[:specs]).to contain_exactly(end_with('spec/a/2/test1_spec.rb'), end_with('spec/a/1_spec.rb'))
    end
    it 'many_patterns' do
      jobs = project_dis.distribute_jobs(RSpec.current_example.description, 1)
      expect(jobs.size).to eq 4
      jobs = project_dis.distribute_jobs(RSpec.current_example.description, 5)
      expect(jobs.size).to eq 5
    end
    it 'label_exp_different' do
      jobs = project_dis.distribute_jobs(RSpec.current_example.description, 1)
      expect(jobs.size).to eq 2
    end
    it 'with_one_exclude_pattern' do
      jobs = project_dis.distribute_jobs(RSpec.current_example.description, 5)
      expect(jobs.size).to eq 4
      jobs.each do |job|
        expect(job[:specs].size).to eq 1
        expect(job[:specs]).not_to include(match(/exclude_.*_spec\.rb/))
      end
    end
    it 'with_many_exclude_pattern' do
      jobs = project_dis.distribute_jobs(RSpec.current_example.description, 1)
      expect(jobs.size).to eq 2
      jobs.each do |job|
        expect(job[:specs]).not_to include(match(/exclude_.*_spec\.rb/))
        expect(job[:specs]).not_to include(match(/broken_.*_spec\.rb/))
      end
    end
    it 'pattern_with_locations' do
      jobs = project_dis.distribute_jobs(RSpec.current_example.description, 1)
      expect(jobs.size).to eq 2
      all_spec_paths = jobs.map { |job| job[:specs] }.flatten
      expect(all_spec_paths.size).to eq 5
      expect(all_spec_paths).to include('spec/a/2/test1_spec.rb:13', 'spec/a/1_spec.rb:13:16')
    end
    it 'pattern_with_ids_no_inherit' do
      jobs = project_dis.distribute_jobs(RSpec.current_example.description, 1)
      expect(jobs.size).to eq 2
      all_spec_paths = jobs.map { |job| job[:specs] }.flatten
      expect(all_spec_paths.size).to eq 5
      expect(all_spec_paths).to include('spec/a/2/test1_spec.rb[1:1:1:1]', 'spec/a/1_spec.rb[1:1:1,1:1:2]')
    end
    it 'pattern_with_ids_inherit' do
      jobs = project_dis.distribute_jobs(RSpec.current_example.description, 1)
      expect(jobs.size).to eq 2
      all_spec_paths = jobs.map { |job| job[:specs] }.flatten
      expect(all_spec_paths.size).to eq 5
      expect(all_spec_paths).to include('spec/a/2/test1_spec.rb[1:1]', 'spec/a/1_spec.rb[1:2]')
    end
    it 'spec_without_profile_declare' do
      expect do
        project_dis.distribute_jobs(RSpec.current_example.description, 1)
      end.to raise_error(RuntimeError, /没有ci profile配置/)
    end
  end
end