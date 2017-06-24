# @env begin
#   *1:type=yyy,cfg.member.size>=2,label.label_x=a
#   &1.cfg.member
#   type=xxx
#   type=xxx
# @end

require_relative '../.share_contexts/a_spec'

describe __FILE__ do
  include_context :shared_context_a

  it 'thing1' do
    true.should == true
  end
  context 'thing2' do
    it 'step1' do
      true.should == true
    end
    it 'step2' do
      true.should == true
    end
  end
end