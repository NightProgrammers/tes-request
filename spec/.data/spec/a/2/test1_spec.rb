# @env begin
#   *1:type=yyy,cfg.member.size>=2,label.label_x=a
#   &1.cfg.member
#   type=xxx
#   type=xxx
# @end

require_relative '../../.share_contexts/a_spec'

describe __FILE__ do
  include_context :shared_context_a

  it 'thing1' do
    true.should == false
  end
  it 'thing2' do
    true.should == false
  end
end