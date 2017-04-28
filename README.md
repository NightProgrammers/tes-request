# Tes::Request

TES(Test Env Service) request profile struct and manager lib

[![Build Status](https://travis-ci.org/wuhuizuo/tes-request.svg)](https://travis-ci.org/wuhuizuo/tes-request)

## Installation

Add this line to your application's Gemfile:

    source "https://rubygems.org"
    gem 'tes-request'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install tes-request
    
## Usage

Given you project root path: `/project/root/path`, and there has file `.ci.yml`, file contents as follow:

```yml
# file .ci.yml
---
with_one_exclude_pattern:
  spec:
    pattern:
    - spec/a/**/*_spec.rb
    - spec/b/**/*_spec.rb
    exclude_pattern: spec/**/exclude_*_spec.rb
```

    
And `spec/**/*_spec.rb` has content:

```ruby
# file spec/**/*_spec.rb all have the content part in the head:
# @env begin
#   *1:type=cluster,cfg.member.size>=2,cfg.vs_enable=1
#   &1.cfg.member
#   type=storage_iscsi
#   type=storage_iscsi
# @distribution -standalone
# @end

describe 'abc' do
  # more ...
end
```

Then you need to slice all spec script to several paralleled jobs.

**Step:**

1. install this gem
2. run cmds like:

```bash
tes-ci-slicer properties apps/test_project func_test 16 apps/test_project/res_attr_add_map.json
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at http://200.200.0.36/vtt/tes-request. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

