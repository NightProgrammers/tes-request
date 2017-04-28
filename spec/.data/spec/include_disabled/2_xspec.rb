# @env begin
#   *1:type=yyy,cfg.member.size>=2
#   &1.cfg.member
#   type=xxx
#   type=zzz
# @end

describe __FILE__ do
  it 'thing1' do
    true.should == false
  end
end