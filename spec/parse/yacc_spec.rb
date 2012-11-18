require "rly"
require "rly/parse/grammar"

describe Rly::Yacc do
  it "acceps a set of rules" do
    expect {
      Class.new(Rly::Yacc) do
        rule 'statement : expression' do |e|
          @val = e
        end
      end
      } .not_to raise_error
  end

  it "creates a grammar on first class instantiation" do
    pending "implement full grammar-parsing stack"
    testParser = Class.new(Rly::Yacc) do
      rule 'statement : VALUE' do |v|
        @val = v
      end
    end
    testParser.grammar.should be_nil
    p = testParser.new(double(Rly::Lex))
    testParser.grammar.should_not be_nil
    testParser.grammar.should be_kind_of(Rly::Grammar)
  end

  it "accepts an instance of lexer as an argument" do
    testParser = Class.new(Rly::Yacc) do
      rule 'statement : VALUE' do |v|
        @val = v
      end
    end
    
    m = double('lexer')

    expect {
      p = testParser.new(m)
      p.lex.should == m
    } .not_to raise_error
  end

  it "can use built in lexer if one is defined" do
    testParser = Class.new(Rly::Yacc) do
      lexer do
        token :FIRST, /[a-z]+/
      end

      rule 'statement : VALUE' do |v|
        @val = v
      end
    end

    p = testParser.new
    p.lex.should be_kind_of(Rly::Lex)
  end

  it "raises error if no lexer is built in and no given" do
    testParser = Class.new(Rly::Yacc) do
      rule 'statement : VALUE' do |v|
        @val = v
      end
    end

    expect { testParser.new } .to raise_error(ArgumentError)
  end
end
