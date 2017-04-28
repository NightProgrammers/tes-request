shared_context :shared_context_a do
  before(:all) { puts 'before_all in shared_context_a' }
  after(:all) { puts 'after_all in shared_context_a' }
end