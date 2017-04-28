# @env begin
#   *1:type=yyy
#   &1.cfg.member
#   type=abc
#   type=edf
# @end

describe __FILE__ do
  it 'thing1' do
    true.should == false
  end
end