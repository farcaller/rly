module Rly
  class LRTable
    def initialize(grammar, method=:lalr)
      raise ArgumentError unless [:lalr, :slr].include?(method)

      @grammar = grammar
      @lr_method = method

      @lr_action = {}
      @lr_goto = {}
      @lr_productions = grammar.productions
      @lr_goto_cache = {}
      @lr0_cidhash = {}

      @add_count = 0

      @sr_conflict = 0
      @rr_conflict = 0
      @conflicts = []

      @sr_conflicts = []
      @rr_conflicts = []
    end
  end
end
