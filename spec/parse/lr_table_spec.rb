require "rly"
require "rly/parse/grammar"
require "rly/parse/lr_table"

describe Rly::LRTable do
  before :each do
    g = Rly::Grammar.new([:NUMBER])

    g.set_precedence('+', :left, 1)
    g.set_precedence('-', :left, 1)

    g.add_production(:statement, [:expression])
    g.add_production(:expression, [:expression, '+', :expression])
    g.add_production(:expression, [:expression, '-', :expression])
    g.add_production(:expression, [:NUMBER])

    g.set_start

    g.build_lritems

    @t = Rly::LRTable.new(g)
  end

  it "computes the LR(0) closure operation on I, where I is a set of LR(0) items" do
    @t.instance_eval do
      lr0_c = lr0_closure([@grammar.productions[0].lr_next])

      lr0_c.length.should == 5
      lr0_c.length.times do |i|
        lr0_c[i].should == @grammar.productions[i].lr_next
      end
    end
  end

  it "computes the LR(0) goto function goto(I,X) where I is a set of LR(0) items and X is a grammar symbol" do
    @t.instance_eval do
      lr0_c = lr0_closure([@grammar.productions[0].lr_next])

      lr0_g = lr0_goto(lr0_c, :statement)

      lr0_g.length.should == 1
      lr0_g[0].name.should == :"S'"
      lr0_g[0].prod.should == [:statement, :'.']

      lr0_g = lr0_goto(lr0_c, :expression)

      lr0_g.length.should == 3
      lr0_g[0].name.should == :statement
      lr0_g[0].prod.should == [:expression, :'.']
      lr0_g[1].name.should == :expression
      lr0_g[1].prod.should == [:expression, :'.', '+', :expression]
      lr0_g[2].name.should == :expression
      lr0_g[2].prod.should == [:expression, :'.', '-', :expression]
    end
  end

  it "computes the LR(0) sets of item function" do
    @t.instance_eval do
      lr0_i = lr0_items

      reflist = Set.new(["S' -> . statement|statement -> . expression|expression -> . expression + expression|expression -> . expression - expression|expression -> . NUMBER",
        "S' -> statement .",
        "statement -> expression .|expression -> expression . + expression|expression -> expression . - expression",
        "expression -> NUMBER .",
        "expression -> expression + . expression|expression -> . expression + expression|expression -> . expression - expression|expression -> . NUMBER",
        "expression -> expression - . expression|expression -> . expression + expression|expression -> . expression - expression|expression -> . NUMBER",
        "expression -> expression + expression .|expression -> expression . + expression|expression -> expression . - expression",
        "expression -> expression - expression .|expression -> expression . + expression|expression -> expression . - expression"])

      lr0_i.length.should == reflist.length
      Set.new(lr0_i.map { |a| a.map { |k| k.to_s } .join('|') }).inspect .should == reflist.inspect
    end
  end

  it "creates a dictionary containing all of the non-terminals that might produce an empty production." do
    # TODO: write a better spec
    @t.instance_eval do
      compute_nullable_nonterminals.should == {}
    end
  end

  it "finds all of the non-terminal transitions" do
    @t.instance_eval do
      find_nonterminal_transitions(lr0_items).should == [[0, :statement], [0, :expression], [4, :expression], [5, :expression]]
    end
  end

  it "computes the DR(p,A) relationships for non-terminal transitions" do
    @t.instance_eval do
      lr0_i = lr0_items
      nullable = compute_nullable_nonterminals
      trans = find_nonterminal_transitions(lr0_i)

      dr_relation(lr0_i, trans[0], nullable).should == [:'$end']
      dr_relation(lr0_i, trans[1], nullable).should == ['+', '-']
    end
  end

  it "computes the READS() relation (p,A) READS (t,C)" do
    # TODO: write a better spec
    @t.instance_eval do
      lr0_i = lr0_items
      nullable = compute_nullable_nonterminals
      trans = find_nonterminal_transitions(lr0_i)

      reads_relation(lr0_i, trans[0], nullable).should == []
      reads_relation(lr0_i, trans[1], nullable).should == []
    end
  end

  it "computes the read sets given a set of LR(0) items" do
    @t.instance_eval do
      lr0_i = lr0_items
      nullable = compute_nullable_nonterminals
      trans = find_nonterminal_transitions(lr0_i)

      compute_read_sets(lr0_i, trans, nullable).should == {
        [0, :statement]  => [:'$end'],
        [5, :expression] => ['+', '-'],
        [4, :expression] => ['+', '-'],
        [0, :expression] => ['+', '-']
      }
    end
  end

  it "determines the lookback and includes relations" do
    @t.instance_eval do
      lr0_i = lr0_items
      nullable = compute_nullable_nonterminals
      trans = find_nonterminal_transitions(lr0_i)

      lookd, included = compute_lookback_includes(lr0_i, trans, nullable)

      included.should == {
        [5, :expression] => [ [0, :expression], [4, :expression], [5, :expression], [5, :expression] ],
        [4, :expression] => [ [0, :expression], [4, :expression], [4, :expression], [5, :expression] ],
        [0, :expression] => [ [0, :statement] ]
      }

      lookd = lookd.each_with_object({}) { |(k, v), h| h[k] = v.map { |n,i| [n, i.to_s] } }
      
      # NOTE: this one goes not map 1-1 to pry as we have differencies in lr0_items order. Looks valid though.
      expected = {
        [0, :statement] => [ [2, "statement -> expression ."] ],
        [0, :expression]=> [
          [6, "expression -> expression + expression ."],
          [6, "expression -> expression . + expression"],
          [6, "expression -> expression . - expression"],
          [7, "expression -> expression - expression ."],
          [7, "expression -> expression . + expression"],
          [7, "expression -> expression . - expression"],
          [3, "expression -> NUMBER ."]
        ],
        [4, :expression] => [
        [6, "expression -> expression + expression ."],
          [6, "expression -> expression . + expression"],
          [6, "expression -> expression . - expression"],
          [7, "expression -> expression - expression ."],
          [7, "expression -> expression . + expression"],
          [7, "expression -> expression . - expression"],
          [3, "expression -> NUMBER ."]
        ],
        [5, :expression] => [
          [6, "expression -> expression + expression ."],
          [6, "expression -> expression . + expression"],
          [6, "expression -> expression . - expression"],
          [7, "expression -> expression - expression ."],
          [7, "expression -> expression . + expression"],
          [7, "expression -> expression . - expression"],
          [3, "expression -> NUMBER ."]
        ]}

      lookd.should == expected

    end
  end

  it "computes the follow sets given a set of LR(0) items, a set of non-terminal transitions, a readset, and an include set" do
    @t.instance_eval do
      lr0_i = lr0_items
      nullable = compute_nullable_nonterminals
      trans = find_nonterminal_transitions(lr0_i)
      readsets = compute_read_sets(lr0_i, trans, nullable)
      lookd, included = compute_lookback_includes(lr0_i, trans, nullable)

      compute_follow_sets(trans, readsets, included).should == {
        [0, :statement] => [:'$end'],
        [5, :expression] => ['+', '-', :'$end'],
        [4, :expression] => ['+', '-', :'$end'],
        [0, :expression] => ['+', '-', :'$end']
      }
    end
  end

  it "attaches the lookahead symbols to grammar rules" do
    pending "verify that values in LRItem#lookaheads are meaningful"
    @t.instance_eval do
      lr0_i = lr0_items
      nullable = compute_nullable_nonterminals
      trans = find_nonterminal_transitions(lr0_i)
      readsets = compute_read_sets(lr0_i, trans, nullable)
      lookd, included = compute_lookback_includes(lr0_i, trans, nullable)
      followsets = compute_follow_sets(trans, readsets, included)

      add_lookaheads(lookd, followsets)
    end
  end

  it "parses the table" do
    expect { @t.parse_table } .not_to raise_error
  end
end
