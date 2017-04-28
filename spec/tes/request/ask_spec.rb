describe Tes::Request::Ask do
  def ask(str)
    Tes::Request::Ask.new(str)
  end

  context :<=> do
    it '属性多少差异比较' do
      expect(ask('hello=1')).to be == ask('hello=1')
      expect(ask('hello=1,name=zwh')).to be >= ask('hello=1')
      expect(ask('hello=1,name=zwh')).to be > ask('hello=1')
      expect(ask('hello=1')).to be <= ask('hello=1,name=zwh,sex=man')
      expect(ask('hello=1')).to be <= ask('hello=1')
    end

    it '相似表达式的比较' do
      expect(ask('hello=1,type=cluster,vs_enable=1')).to be > ask('hello>0,type=cluster,vs_enable=1')
      expect(ask('hello=1,type=cluster,vs_enable=1')).to be > ask('hello>0,type=cluster,vs_enable<=1')
      expect(ask('hello=1,type=cluster,vs_enable=1')).to be > ask('hello>0,type=cluster,vs_enable<=1')
    end
    it 'zwh' do
      a = ask 'type=cluster,cfg.member.size>=2,label.for=bdd'
      b = ask 'type=cluster,cfg.member.size>=1'
      expect(a).to be > b
    end

    it '冲突无法比较' do
      expect(ask('hello=1,vs_enable=1') <=> ask('hello>0,vs_enable<1')).to be_nil
      expect(ask('hello=1,vs_enable=1') <=> ask('hello=2')).to be_nil
      expect(ask('hello>2,vs_enable=1') <=> ask('hello=2')).to be_nil
      expect(ask('hello=2,vs_enable=1') <=> ask('hello=2,vs_enable=0')).to be_nil
    end
  end
  context :merge_able? do
    it 'false' do
      expect(ask('hello=2,vs_enable=1')).not_to be_merge_able ask('hello=2,vs_enable=0')
    end
  end
end