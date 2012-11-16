require "set"

module Rly
  class LRTable
    MAXINT = (2**(0.size * 8 -2) -1)

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

        asyms = Set.new
        c_i.each { |ii| ii.usyms.each { |s| asyms << s } }

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

    def compute_nullable_nonterminals
      nullable = {}
      num_nullable = 0
      while true
        @grammar.productions[1..-1].each do |p|
          if p.length == 0
            nullable[p.name] = 1
            next
          end
          found_t = false
          p.prod.each do |t|
            unless nullable[t]
              found_t = true
              break
            end
          end
          nullable[p.name] = 1 unless found_t
        end
        break if nullable.length == num_nullable
        num_nullable = nullable.length
      end
      nullable
    end

    def find_nonterminal_transitions(c)
      trans = []
      c.each_with_index do |a, state|
        a.each do |p|
          if p.lr_index < p.length - 1
            next_prod = p.prod[p.lr_index+1]
            if @grammar.nonterminals[next_prod]
              t = [state, next_prod]
              trans << t unless trans.include?(t)
            end
          end
        end
      end
      trans
    end

    def compute_read_sets(c, ntrans, nullable)
      fp = lambda { |x| dr_relation(c, x, nullable) }
      r = lambda { |x| reads_relation(c, x, nullable) }
      digraph(ntrans, r, fp)
    end

    def dr_relation(c, trans, nullable)
      dr_set = {}
      state, n = trans
      terms = []

      g = lr0_goto(c[state], n)
      g.each do |p|
        if p.lr_index < p.length - 1
          a = p.prod[p.lr_index+1]
          if @grammar.terminals.include?(a)
            terms << a unless terms.include?(a)
          end
        end
      end

      terms << :'$end' if state == 0 && n == @grammar.productions[0].prod[0]
      
      terms
    end

    def reads_relation(c, trans, empty)
        rel = []
        state, n = trans

        g = lr0_goto(c[state], n)
        j = @lr0_cidhash[g.hash] || -1
        g.each do |p|
          if p.lr_index < p.length - 1
            a = p.prod[p.lr_index + 1]
            rel << [j, a] if empty.include?(a)
          end
        end

        rel
    end

    def digraph(x, r, fp)
      n = {}
      x.each { |xx| n[xx] = 0 }
      stack = []
      f = {}
      x.each do |xx|
        traverse(xx, n, stack, f, x, r, fp) if n[xx] == 0
      end
      f
    end

    def traverse(xx, n, stack, f, x, r, fp)
      stack.push(xx)
      d = stack.length
      n[xx] = d
      f[xx] = fp.call(xx)

      rel = r.call(xx)
      rel.each do |y|
        traverse(y, n, stack, f, x, r, fp) if n[y] == 0
        
        n[xx] = [n[xx], n[y]].min

        arr = f[y] || []
        arr.each do |a|
          f[xx] << a unless f[xx].include?(a)
        end
      end
      if n[xx] == d
        n[stack[-1]] = MAXINT
        f[stack[-1]] = f[xx]
        element = stack.pop()
        while element != xx
          n[stack[-1]] = MAXINT
          f[stack[-1]] = f[xx]
          element = stack.pop()
        end
      end
    end

    def compute_lookback_includes(c, trans, nullable)
      lookdict = {}
      includedict = {}

      dtrans = trans.each_with_object({}) { |k, h| h[k] = 1 }

      trans.each do |state, n|
        lookb = []
        includes = []
        c[state].each do |p|
          next unless p.name == n

          lr_index = p.lr_index
          j = state
          while lr_index < p.length - 1
            lr_index = lr_index + 1
            t = p.prod[lr_index]

            if dtrans.include?([j,t])
              li = lr_index + 1
              escaped = false
              while li < p.length
                if @grammar.terminals[p.prod[li]]
                  escaped = true
                  break
                end
                unless nullable[p.prod[li]]
                  escaped = true
                  break
                end
                li = li + 1
              end
              includes << [j,t] unless escaped
            end

            g = lr0_goto(c[j],t)
            j = @lr0_cidhash[g.hash] || -1
          end

          c[j].each do |r|
            next unless r.name == p.name
            next unless r.length == p.length
            i = 0
            escaped = false
            while i < r.lr_index
              unless r.prod[i] == p.prod[i+1]
                escaped = true
                break
              end
              i = i + 1
            end
            lookb << [j,r] unless escaped
          end
        end
        includes.each do |i|
          includedict[i] = [] unless includedict[i]
          includedict[i] << [state, n]
        end
        lookdict[[state,n]] = lookb
      end

      [lookdict, includedict]
    end

    def compute_follow_sets(ntrans, readsets, inclsets)
      fp = lambda { |x| readsets[x] }
      r  = lambda { |x| inclsets[x] || [] }
      digraph(ntrans, r, fp)
    end

    def add_lookaheads(lookbacks, followset)
      lookbacks.each do |trans, lb|
        lb.each do |state, p|
          p.lookaheads[state] = [] unless p.lookaheads[state]
          f = followset[trans] || []
          f.each do |a|
            p.lookaheads[state] << a unless p.lookaheads[state].include?(a)
          end
        end
      end
    end
  end
end
