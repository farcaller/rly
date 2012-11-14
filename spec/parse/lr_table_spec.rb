require "rly"
require "rly/parse/grammar"
require "rly/parse/lr_table"

describe Rly::LRTable do
  before :each do
    @g = Rly::Grammar.new([:NUMBER])

    @g.set_precedence('+', :left, 1)
    @g.set_precedence('-', :left, 1)

    @g.add_production(:statement, [:expression])
    @g.add_production(:expression, [:expression, '+', :expression])
    @g.add_production(:expression, [:expression, '-', :expression])
    @g.add_production(:expression, [:NUMBER])

    @g.set_start

    @g.build_lritems

    @t = Rly::LRTable.new(@g)
  end

  it "should compute the LR(0) closure operation on I, where I is a set of LR(0) items" do
    lr0_c = @t.send(:lr0_closure, [@g.productions[0].lr_next])

    lr0_c.length.should == @g.productions.length
    lr0_c.length.times do |i|
      lr0_c[i].should == @g.productions[i].lr_next
    end
  end

  it "should compute the LR(0) goto function goto(I,X) where I is a set of LR(0) items and X is a grammar symbol" do
    lr0_c = @t.send(:lr0_closure, [@g.productions[0].lr_next])

    lr0_g = @t.send(:lr0_goto, lr0_c, :statement)

    lr0_g.length.should == 1
    lr0_g[0].name.should == :"S'"
    lr0_g[0].prod.should == [:statement, :'.']

    lr0_g = @t.send(:lr0_goto, lr0_c, :expression)

    lr0_g.length.should == 3
    lr0_g[0].name.should == :statement
    lr0_g[0].prod.should == [:expression, :'.']
    lr0_g[1].name.should == :expression
    lr0_g[1].prod.should == [:expression, :'.', '+', :expression]
    lr0_g[2].name.should == :expression
    lr0_g[2].prod.should == [:expression, :'.', '-', :expression]
  end

  it "should compute the LR(0) sets of item function" do
    lr0_i = @t.send(:lr0_items)

    lr0_i.length.should == 1
    items = lr0_i[0].map do |i|
      i.should be_kind_of(Rly::LRItem)
      i.to_s
    end

    items.join("\t").should == "S' -> . statement" +
                               "\tstatement -> . expression" +
                               "\texpression -> . expression + expression" +
                               "\texpression -> . expression - expression" +
                               "\texpression -> . NUMBER"
  end
end
