require "rly"
require "rly/parse/rule_parser"

describe Rly::RuleParser do
  it "parses a simple rule string" do
    s = 'expression : expression "+" expression
                    | expression "-" expression
                    | expression "*" expression
                    | expression "/" expression'
    p = Rly::RuleParser.new

    p.parse(s)

    p.productions.length.should == 4
    p.productions[0].should == [:expression, [:expression, '+', :expression]]
    p.productions[1].should == [:expression, [:expression, '-', :expression]]
    p.productions[2].should == [:expression, [:expression, '*', :expression]]
    p.productions[3].should == [:expression, [:expression, '/', :expression]]
  end
end
