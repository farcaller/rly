require "set"
require "rly/parse/ply_dump"

module Rly
  class LRTable
    MAXINT = (2**(0.size * 8 -2) -1)

    attr_reader :lr_action, :lr_goto, :lr_productions

    def initialize(grammar, method=:LALR)
      raise ArgumentError unless [:LALR, :SLR].include?(method)

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

      grammar.build_lritems
      grammar.compute_first
      grammar.compute_follow
    end

    def parse_table(log=PlyDump.stub)
      productions = @grammar.productions
      precedence = @grammar.precedence

      actionp = {}

      log.info("Parsing method: %s", @lr_method)

      c = lr0_items

      add_lalr_lookaheads(c) if @lr_method == :LALR

      # Build the parser table, state by state
      st = 0
      c.each do |i|
        # Loop over each production in I
        actlist = []              # List of actions
        st_action  = {}
        st_actionp = {}
        st_goto    = {}
        log.info("")
        log.info("state %d", st)
        log.info("")
        i.each { |p| log.info("    (%d) %s", p.index, p.to_s) }
        log.info("")

        i.each do |p|
          if p.length == p.lr_index + 1
            if p.name == :"S'"
              # Start symbol. Accept!
              st_action[:"$end"] = 0
              st_actionp[:"$end"] = p
            else
              # We are at the end of a production.  Reduce!
              if @lr_method == :LALR
                laheads = p.lookaheads[st]
              else
                laheads = @grammar.follow[p.name]
              end
              laheads.each do |a|
                actlist << [a, p, sprintf("reduce using rule %d (%s)", p.index, p)]
                r = st_action[a]
                if r
                  # Whoa. Have a shift/reduce or reduce/reduce conflict
                  if r > 0
                    # Need to decide on shift or reduce here
                    # By default we favor shifting. Need to add
                    # some precedence rules here.
                    sprec, slevel = productions[st_actionp[a].index].precedence
                    rprec, rlevel = precedence[a] || [:right, 0]
                    if (slevel < rlevel) || ((slevel == rlevel) && (rprec == :left))
                      # We really need to reduce here.
                      st_action[a] = -p.index
                      st_actionp[a] = p
                      if ! slevel && ! rlevel
                        log.info("  ! shift/reduce conflict for %s resolved as reduce",a)
                        @sr_conflicts << [st, a, 'reduce']
                      end
                      productions[p.index].reduced += 1
                    elsif (slevel == rlevel) && (rprec == :nonassoc)
                      st_action[a] = nil
                    else
                      # Hmmm. Guess we'll keep the shift
                      unless rlevel
                        log.info("  ! shift/reduce conflict for %s resolved as shift",a)
                        @sr_conflicts << [st,a,'shift']
                      end
                    end
                  elsif r < 0
                      # Reduce/reduce conflict.   In this case, we favor the rule
                      # that was defined first in the grammar file
                      oldp = productions[-r]
                      pp = productions[p.index]
                      if oldp.line > pp.line
                        st_action[a] = -p.index
                        st_actionp[a] = p
                        chosenp = pp
                        rejectp = oldp
                        productions[p.index].reduced += 1
                        productions[oldp.index].reduced -= 1
                      else
                        chosenp,rejectp = oldp,pp
                      end
                      @rr_conflicts << [st, chosenp, rejectp]
                      log.info("  ! reduce/reduce conflict for %s resolved using rule %d (%s)", a, st_actionp[a].index, st_actionp[a])
                  else
                    raise RuntimeError("Unknown conflict in state #{st}")
                  end
                else
                  st_action[a] = -p.index
                  st_actionp[a] = p
                  productions[p.index].reduced += 1
                end
              end
            end
          else
            a = p.prod[p.lr_index+1]       # Get symbol right after the "."
            if @grammar.terminals.include?(a)
              g = lr0_goto(i, a)
              j = @lr0_cidhash[g.hash] || -1
              if j >= 0
                # We are in a shift state
                actlist << [a, p, sprintf("shift and go to state %d", j)]
                r = st_action[a]
                if r
                  # Whoa have a shift/reduce or shift/shift conflict
                  if r > 0
                    if r != j
                      raise RuntimeError("Shift/shift conflict in state #{st}")
                    end
                  elsif r < 0
                    # Do a precedence check.
                    #   -  if precedence of reduce rule is higher, we reduce.
                    #   -  if precedence of reduce is same and left assoc, we reduce.
                    #   -  otherwise we shift
                    rprec, rlevel = productions[st_actionp[a].index].precedence
                    sprec, slevel = precedence[a] || [:right, 0]
                    if (slevel > rlevel) || ((slevel == rlevel) && (rprec == :right))
                      # We decide to shift here... highest precedence to shift
                      productions[st_actionp[a].index].reduced -= 1
                      st_action[a] = j
                      st_actionp[a] = p
                      unless rlevel
                        log.info("  ! shift/reduce conflict for %s resolved as shift",a)
                        @sr_conflicts << [st, a, 'shift']
                      end
                    elsif (slevel == rlevel) && (rprec == :nonassoc)
                      st_action[a] = nil
                    else
                      # Hmmm. Guess we'll keep the reduce
                      if ! slevel && ! rlevel
                        log.info("  ! shift/reduce conflict for %s resolved as reduce",a)
                        @sr_conflicts << [st, a, 'reduce']
                      end
                    end
                  else
                    raise RuntimeError("Unknown conflict in state #{st}")
                  end
                else
                  st_action[a] = j
                  st_actionp[a] = p
                end
              end
            end
          end
        end

        # Print the actions associated with each terminal
        _actprint = {}
        actlist.each do |a, p, m|
          if st_action[a]
            if p == st_actionp[a]
              log.info("    %-15s %s",a,m)
              _actprint[[a,m]] = 1
            end
          end
        end
        log.info("")
        # Print the actions that were not used. (debugging)
        not_used = false
        actlist.each do |a, p, m|
          if st_action[a]
            unless p == st_actionp[a]
              unless _actprint[[a,m]]
                log.debug("  ! %-15s [ %s ]", a, m)
                not_used = true
                _actprint[[a,m]] = 1
              end
            end
          end
        end
        log.debug("") if not_used

        # Construct the goto table for this state

        nkeys = {}
        i.each do |ii|
          ii.usyms.each do |s|
            nkeys[s] = nil if @grammar.nonterminals.include?(s)
          end
        end
        nkeys.each do |n, _|
          g = lr0_goto(i, n)
          j = @lr0_cidhash[g.hash] || -1
          if j >= 0
            st_goto[n] = j
            log.info("    %-30s shift and go to state %d",n,j)
          end
        end

        @lr_action[st] = st_action
        actionp[st] = st_actionp
        @lr_goto[st] = st_goto
        st += 1
      end
    end

    private
    def add_lalr_lookaheads(c)
      nullable = compute_nullable_nonterminals
      trans = find_nonterminal_transitions(c)
      readsets = compute_read_sets(c, trans, nullable)
      lookd, included = compute_lookback_includes(c, trans, nullable)
      followsets = compute_follow_sets(trans, readsets, included)
      add_lookaheads(lookd, followsets)
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
