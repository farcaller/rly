module Rly
  class LRTable
    def initialize(grammar, method=:lalr)
      raise ArgumentError unless [:lalr, :slr].include?(method)

      @grammar = grammar
      @lr_method = method

      @action = {}
      @goto = {}
      @lr_productions = grammar.productions
      @lr_goto_cache = {}
      @lr0_cidhash = {}

      @add_count = 0

      @sr_conflict = 0
      @rr_conflict = 0
      @conflicts = []

      @sr_conflicts = []
      @rr_conflicts = []

      grammar.build_lritems
      grammar.compute_first
      grammar.compute_follow
    end

    private
    def parse_table
      productions = @grammar.productions
      precedence = @grammar.precedence

      actionp = {}

      c = lr0_items
    end

    def lr0_closure(i)
      @add_count += 1

      # Add everything in I to J
      j = i.dup
      didadd = true
      while didadd
        didadd = false
        j.each do |k|
          k.lr_after.each do |x|
            next if x.lr0_added == @add_count
            # Add B --> .G to J
            j << x.lr_next
            x.lr0_added = @add_count
            didadd = true
          end
        end
      end
      j
    end

    def lr0_goto(i, x)
      g = @lr_goto_cache[[i.hash, x]]
      return g if g

      s = @lr_goto_cache[x]
      unless s
        s = {}
        @lr_goto_cache[x] = s
      end

      gs = []
      i.each do |p|
        n = p.lr_next
        if n and n.lr_before == x
          s1 = s[n.hash]
          unless s1
            s1 = {}
            s[n.hash] = s1
          end
          gs << n
          s = s1
        end
      end
      g = s[:'$end']
      unless g
        if gs
          g = lr0_closure(gs)
          s[:'$end'] = g
        else
          s[:'$end'] = gs
        end
      end
      @lr_goto_cache[[i.hash,x]] = g
      g
    end

    def lr0_items
      c = [ lr0_closure([@grammar.productions[0].lr_next]) ]

      c.each_with_index { |c_i, j| @lr0_cidhash[c_i.hash] = j }

      i = 0
      while i < c.length
        c_i = c[i]
        i += 1

        asyms = {}
        c_i.each { |ii| ii.usyms.each { |s| asyms[s] = nil } }

        asyms.each do |x|
          g = lr0_goto(c_i, x)
          next if g.empty?
          next if @lr0_cidhash[g.hash]
          @lr0_cidhash[g.hash] = c.length
          c << g
        end
      end
      c
    end
  end
end
