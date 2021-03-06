# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tes/request/version'

Gem::Specification.new do |spec|
  spec.name = 'tes-request'
  spec.version = Tes::Request::VERSION
  spec.authors = ['wuhuizuo']
  spec.email = ['wuhuizuo@126.com']

  spec.summary = %q{Request libs and bins for TES(Test Env Service)}
  spec.description = %q{Provide Tes-Client, Tes-Provider to use public Logic and data struct}
  spec.homepage = 'https://github.com/NightProgrammers/tes-request'
  spec.license = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  else
    raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.'
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.bindir = 'bin'
  spec.executables = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'java-properties', '~> 0.2'
  spec.add_runtime_dependency 'httpclient', '~> 2.8.3'
  spec.add_development_dependency 'rake', '~> 12.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'bundler', '~> 1.13'

  spec.required_ruby_version = '~> 2.0'
end
