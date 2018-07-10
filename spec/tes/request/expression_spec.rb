describe Tes::Request::Expression do
  def ep(str)
    Tes::Request::Expression.new str
  end

  context :initialize do
    it 'value is uuid format' do
      v = '33da8c60-6663-0136-50a4-7caa1402314f'
      e = ep("id=#{v}")
      expect(e.data).to include(left_exp: 'id', op: '==', expect_val: v)
    end
    it 'value is float format' do
      vs = ['-123.456', '123.456', '0.35', '45678.0']
      vs.each do |v|
        expect(ep("id=#{v}").data[:expect_val]).to eq(v.to_f)
      end
    end
    it 'value is version format' do
      vs = ['1.2.3', 'v2.0']
      vs.each do |v|
        expect(ep("id=#{v}").data[:expect_val]).to eq(v)
      end
    end
  end

  context :<=> do
    context 'result:-1' do
      it('type<124 <=> type<123') {expect(ep('type<124') <=> ep('type<123')).to be == -1}
      it('type>=124 <=> type=124') {expect(ep('type>=124') <=> ep('type=124')).to be == -1}
      it('hello>=1 <=> hello=2') {expect(ep('hello>=1') <=> ep('hello=2')).to be == -1}
      it('vs_enable<=1 <=> vs_enable=0') {expect(ep('vs_enable<=1') <=> ep('vs_enable=0')).to be == -1}
    end
    context 'result:0' do
      it('type>=124 <=> type>=124') {expect(ep('type>=124') <=> ep('type>=124')).to be == 0}
    end
    context 'result:1' do
      it('type>=124 <=> type>123') {expect(ep('type>=124') <=> ep('type>123')).to be == 1}
    end
    context 'result:nil' do
      it('type=abc <=> type=123') {expect(ep('type=abc') <=> ep('type=123')).to be_nil}
      it('type]124 <=> type=123') {expect(ep('type>=124') <=> ep('type=123')).to be_nil}
      it('type<=124 <=> type=123') {expect(ep('type>=124') <=> ep('type=123')).to be_nil}
      it('type>=124 <=> type=123') {expect(ep('type>=124') <=> ep('type=123')).to be_nil}
    end
  end

  context :to_s do
    it('label.version=abcX.Y') {expect(ep('label.lang=abc5.1').to_s).to be == 'label.lang==abc5.1'}
    it('label.version=abcX.Y.Z') {expect(ep('label.lang=abc5.1.1').to_s).to be == 'label.lang==abc5.1.1'}
  end


  context :match? do
    it 'hello' do
      ep('a=123').match?({a: 123, type: 'cluster'})
      ep('a>=123').match?({a: 123, type: 'cluster'})
      ep('a>122').match?({a: 123, type: 'cluster'})
      ep('type?').match?({a: 123, type: 'cluster'})
      ep('a?').match?({a: 123, type: 'cluster'})
      ep('!a<123').match?({a: 123, type: 'cluster'})
    end
  end
end
