# @env begin
#   *1:type=yyy,cfg.member.size>=2,label.label_x=1
#   &1.cfg.member
#   type=xxx
#   type=xxx
# @distribute --standalone
# @end

describe __FILE__ do
  it 'thing1' do
    true.should == false
  end
end