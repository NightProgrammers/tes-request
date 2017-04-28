shared_context :shared_context_b do
  before(:all) { puts 'before_all in shared_context_b' }
  after(:all) { puts 'after_all in shared_context_b' }
end