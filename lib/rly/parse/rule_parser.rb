require "rly/lex"
require "rly/parse/grammar"
require "rly/parse/lr_table"

module Rly
  class RuleParser < Yacc
    def self.lexer_class
      return @lexer_class if @lexer_class

      @lexer_class = Class.new(Lex) do
        token :PREC, /\%prec/
        token :ID, /[a-zA-Z_][a-zA-Z_0-9]*/
        token :LITERAL, /"."|'.'/ do |t|
          t.value = t.value[1]
          t
        end
        literals ":|"
        ignore " \t\n"
      end

      @lexer_class
    end

    def grammar
      return @grammar if @grammar

      @grammar = Grammar.new(self.class.lexer_class.terminals)

      @grammar.add_production(:grammar_def, [:grammar]) do |d, g|
        d.value = g.value
      end
      @grammar.add_production(:grammar, [:ID, ':', :rules, :PREC, :ID]) do |g, pname, _, r, _, prec|
        productions = []
        r.value.each do |p|
          productions << [pname.value.to_sym, p, prec.value.to_sym]
        end
        g.value = productions
      end
      @grammar.add_production(:grammar, [:ID, ':', :rules]) do |g, pname, _, r|
        productions = []
        r.value.each do |p|
          productions << [pname.value.to_sym, p, nil]
        end
        g.value = productions
      end
      @grammar.add_production(:rules, [:rule, '|', :rules]) do |rls, r, _, rl|
        rls.value = [r.value] + rl.value
      end
      @grammar.add_production(:rules, [:rule]) do |rl, r|
        rl.value = [r.value]
      end
      @grammar.add_production(:rules, []) do |rl|
        rl.value = [[]]
      end
      @grammar.add_production(:rule, [:tokens]) do |r, tok|
        r.value = tok.value
      end
      @grammar.add_production(:tokens, [:ID, :tokens]) do |t, i, toks|
        t.value = [i.value.to_sym] + toks.value
      end
      @grammar.add_production(:tokens, [:LITERAL, :tokens]) do |t, l, toks|
        t.value = [l.value] + toks.value
      end
      @grammar.add_production(:tokens, [:ID]) do |t, i|
        t.value = [i.value.to_sym]
      end
      @grammar.add_production(:tokens, [:LITERAL]) do |t, l|
        t.value = [l.value]
      end

      @grammar.set_start

      @grammar.build_lritems

      @lr_table = LRTable.new(@grammar)

      @lr_table.parse_table

      @grammar
    end
  end
end
