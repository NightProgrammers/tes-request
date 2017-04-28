describe Tes::Request::Expression do
  def ep(str)
    Tes::Request::Expression.new str
  end

  context :<=> do
    context 'result:-1' do
      it('type<124 <=> type<123') { expect(ep('type<124') <=> ep('type<123')).to be == -1 }
      it('type>=124 <=> type=124') { expect(ep('type>=124') <=> ep('type=124')).to be == -1 }
    end
    context 'result:0' do
      it('type>=124 <=> type>=124') { expect(ep('type>=124') <=> ep('type>=124')).to be == 0 }
    end
    context 'result:1' do
      it('type>=124 <=> type>123') { expect(ep('type>=124') <=> ep('type>123')).to be == 1 }
    end
    context 'result:nil' do
      it('type=abc <=> type=123') { expect(ep('type=abc') <=> ep('type=123')).to be_nil }
      it('type]124 <=> type=123') { expect(ep('type>=124') <=> ep('type=123')).to be_nil }
      it('type<=124 <=> type=123') { expect(ep('type>=124') <=> ep('type=123')).to be_nil }
      it('type>=124 <=> type=123') { expect(ep('type>=124') <=> ep('type=123')).to be_nil }
    end
  end

  context :to_s do
    it('label.version=zh') { expect(ep('label.lang=hci5.1').to_s).to be == 'label.lang=hci5.1' }

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
