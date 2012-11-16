require "rly"
require "rly/parse/grammar"
require "rly/parse/ply_dump"

describe Rly::Grammar do
  it "requires a list of terminals to be initialized" do
    g = Rly::Grammar.new([:NUMBER])
    g.terminals[:NUMBER].should_not be_nil
  end

  it "rejects terminals named in lowercase" do
    expect { Rly::Grammar.new([:test]) } .to raise_error(ArgumentError)
  end

  it "has a default terminal -- error" do
    g = Rly::Grammar.new([])
    g.terminals[:error].should_not be_nil
  end

  context "Precedence specs" do
    it "allows to set precedence" do
      g = Rly::Grammar.new([])
      g.set_precedence('+', :left, 1)
    end

    it "does not allow to set precedence after any productions have been added" do
      g = Rly::Grammar.new([])
      g.add_production(:expression, [:expression, '+', :expression])
      expect { g.set_precedence('+', :left, 1) } .to raise_error(RuntimeError)
    end

    it "does not allow setting precedence several times for same terminal" do
      g = Rly::Grammar.new([])
      g.set_precedence('+', :left, 1)
      expect { g.set_precedence('+', :left, 1) } .to raise_error(ArgumentError)
    end

    it "allows setting only :left, :right or :noassoc precedence associations" do
      g = Rly::Grammar.new([])
      expect { g.set_precedence('+', :bad, 1) } .to raise_error(ArgumentError)
    end
  end

  context "Production specs" do
    it "returns a Production object when adding production" do
      g = Rly::Grammar.new([])
      p = g.add_production(:expression, [:expression, '+', :expression])
      p.should be_a(Rly::Production)
    end

    it "rejects productions not named in lowercase" do
      g = Rly::Grammar.new([])
      expect { g.add_production(:BAD, []) } .to raise_error(ArgumentError)
    end

    it "rejects production named :error" do
      g = Rly::Grammar.new([])
      expect { g.add_production(:error, []) } .to raise_error(ArgumentError)
    end

    it "registers one-char terminals" do
      g = Rly::Grammar.new([])
      g.add_production(:expression, [:expression, '+', :expression])
      g.terminals['+'].should_not be_nil
    end

    it "raises ArgumentError if one-char terminal is not actually an one char" do
      g = Rly::Grammar.new([])
      expect { g.add_production(:expression, [:expression, 'lulz', :expression]) } .to raise_error(ArgumentError)
    end

    it "calculates production precedence based on rightmost terminal" do
      g = Rly::Grammar.new([])
      g.set_precedence('+', :left, 1)
      p = g.add_production(:expression, [:expression, '+', :expression])
      p.precedence.should == [:left, 1]
    end

    it "defaults precedence to [:right, 0]" do
      g = Rly::Grammar.new([])
      p = g.add_production(:expression, [:expression, '+', :expression])
      p.precedence.should == [:right, 0]
    end

    it "adds production to the list of productions" do
      g = Rly::Grammar.new([])
      p = g.add_production(:expression, [:expression, '+', :expression])
      g.productions.count.should == 2
      g.productions.last == p
    end

    it "adds production to the list of productions referenced by names" do
      g = Rly::Grammar.new([])
      p = g.add_production(:expression, [:expression, '+', :expression])
      g.prodnames.count.should == 1
      g.prodnames[:expression].should == [p]
    end

    it "adds production to the list of non-terminals" do
      g = Rly::Grammar.new([])
      p = g.add_production(:expression, [:expression, '+', :expression])
      g.nonterminals[:expression].should_not be_nil
    end

    it "adds production number to referenced terminals" do
      g = Rly::Grammar.new([])
      p = g.add_production(:expression, [:expression, '+', :expression])
      g.terminals['+'].should == [p.index]
    end

    it "adds production number to referenced non-terminals" do
      g = Rly::Grammar.new([])
      p = g.add_production(:expression, [:expression, '+', :expression])
      g.nonterminals[:expression].should == [p.index, p.index]
    end

    it "does not allow duplicate rules" do
      g = Rly::Grammar.new([])
      g.add_production(:expression, [:expression, '+', :expression])
      expect { g.add_production(:expression, [:expression, '+', :expression]) } .to raise_error(ArgumentError)
    end
  end

  context "Start symbol specs" do
    before :each do
      @g = Rly::Grammar.new([])
      p = @g.add_production(:expression, [:expression, '+', :expression])
      @g.set_start()
    end

    it "sets start symbol if it is specified explicitly" do
      @g.start.should == :expression
    end

    it "sets start symbol based on first production if it is not specified explicitly" do
      @g.start.should == :expression
    end

    it "accepts only existing non-terminal as a start" do
      g = Rly::Grammar.new([:NUMBER])
      p = g.add_production(:expression, [:expression, '+', :expression])
      expect { g.set_start(:NUMBER) } .to raise_error(ArgumentError)
      expect { g.set_start(:new_sym) } .to raise_error(ArgumentError)
    end

    it "sets zero rule to :S' -> :start" do
      prod_0 = @g.productions[0]
      prod_0.index.should == 0
      prod_0.name.should == :"S'"
      prod_0.prod.should == [:expression]
    end

    it "adds 0 to start rule nonterminals" do
      @g.nonterminals[:expression][-1].should == 0
    end
  end

  context "LR table generation specs" do
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
    end

    it "builds LR items for grammar" do
      @g.productions.length.should == 5
      items = [2, 2, 4, 4, 2]
      @g.productions.each_with_index do |p, i|
        p.lr_items.count.should == items[i]
      end
    end

    it "sets LR items to correct default values" do
      i = @g.productions[0].lr_items[0]
      i.lr_after.should == [@g.productions[1]]
      i.prod.should == [:'.', :statement]

      i = @g.productions[0].lr_items[1]
      i.lr_after.should == []
      i.prod.should == [:statement, :'.']

      i = @g.productions[2].lr_items[0]
      i.lr_after.should == @g.productions[2..4]
      i.prod.should == [:'.', :expression, '+', :expression]
    end

    it "builds correct FIRST table" do
      first = @g.compute_first
      first.should == {
        :'$end' => [:'$end'],
        '+' => ['+'],
        '-' => ['-'],
        :NUMBER => [:NUMBER],
        :error => [:error],
        :expression => [:NUMBER],
        :statement => [:NUMBER]
      }
    end

    it "builds correct FOLLOW table" do
      @g.compute_first
      follow = @g.compute_follow
      follow.should == { :expression => [:'$end', '+', '-'], :statement => [:'$end'] }
    end
  end

  it "should generate parser.out same as Ply does" do
    pending "thx to python dicts we have a different order of states. ideas?"
    g = Rly::Grammar.new([:NUMBER])

    g.set_precedence('+', :left, 1)
    g.set_precedence('-', :left, 1)

    g.add_production(:statement, [:expression])
    g.add_production(:expression, [:expression, '+', :expression])
    g.add_production(:expression, [:expression, '-', :expression])
    g.add_production(:expression, [:NUMBER])

    g.set_start

    d = Rly::PlyDump.new(g)
    orig = File.join(File.dirname(__FILE__), '..', 'fixtures', 'minicalc_ply_parser.out')
    dst = File.join(File.dirname(__FILE__), '..', 'fixtures', 'minicalc_ply_parser.out.new')

    open(dst, 'w') { |f| f.write(d.to_s) }

    d.to_s.should == open(orig).read
  end
end
