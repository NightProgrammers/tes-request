# @env begin
#   *1:type=yyy,cfg.member.size>=2,label.label_x=b
#   &1.cfg.member
#   type=xxx
#   type=aaa
# @end

require_relative '../.share_contexts/b_spec'

describe __FILE__ do
  include_context :shared_context_b

  it 'thing1' do
    true.should == false
  end
end