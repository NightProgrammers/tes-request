describe Tes::Request::Profile do
  def single_str_p(single_str)
    Tes::Request::Profile.new(single_str.split(';'))
  end

  context '==' do
    it 'yes' do
      a = single_str_p 'type=storage_iscsi;type=storage_iscsi;*1:type=cluster,cfg.member.size>=2;&1.cfg.member'
      b = single_str_p 'type=storage_iscsi;type=storage_iscsi;*1:type=cluster,cfg.member.size>=2;&1.cfg.member'
      expect(a).to eq b
    end
    it 'no' do
      a = single_str_p 'type=storage_iscsi;type=storage_iscsi;*1:type=cluster,cfg.member.size>=2;&1.cfg.member'
      b = single_str_p 'type=storage_iscsi;*1:type=cluster,cfg.member.size>=2;&1.cfg.member'
      expect(a).not_to eq b
    end
  end
  context '>=' do
    it '>' do
      a = single_str_p 'type=storage_iscsi;type=storage_iscsi;*1:type=cluster;&1.cfg.member'
      b = single_str_p 'type=storage_iscsi;*1:type=cluster;&1.cfg.member'
      c = single_str_p '*1:type=cluster;&1.cfg.member'
      d = single_str_p '*1:type=cluster;type=storage_iscsi;&1.cfg.member'
      expect(a).to be > b
      expect(b).to be > c
      expect(a).to be > c
      expect(b).to eq d
      expect(b).to be >= d
      expect(c).not_to be > d
    end
  end

  context '+' do
    it 'a+b==a' do
      a = single_str_p 'type=storage_iscsi;type=storage_iscsi;*1:type=cluster,cfg.member.size>=2;&1.cfg.member'
      b = single_str_p '*1:type=cluster;&1.cfg.member'
      expect { a + b }.not_to raise_error
      expect(a + b).to be == a
      expect(b + a).to be == a
    end
    it 'a+b==c' do
      a = single_str_p '*1:type=cluster,cfg.member.size>=1;&1.cfg.member;type=storage_iscsi'
      b = single_str_p '*2:type=cluster,cfg.member.size>=2;&2.cfg.member'
      c = single_str_p '*1:type=cluster,cfg.member.size>=2;&1.cfg.member;type=storage_iscsi'
      expect(a + b).to be == c
    end
  end
end