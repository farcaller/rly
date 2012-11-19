require "rly/parse/production"
require "rly/parse/lr_item"

module Rly
  class Grammar
    attr_reader :terminals, :nonterminals, :productions, :prodnames, :start, :precedence

    def initialize(terminals)
      @productions = [nil]
      @prodnames = {}
      @prodmap = {}

      @terminals = {}
      terminals.each do |t|
        raise ArgumentError unless t.upcase == t
        @terminals[t] = []
      end
      @terminals[:error] = []

      @nonterminals = {}
      @first = {}
      @follow = {}
      @precedence = {}
      @used_precedence = {}
      @start = nil
    end

    def add_production(name, symbols, enforced_prec=nil, &block)
      raise ArgumentError unless name.downcase == name
      raise ArgumentError if name == :error

      symbols.each do |sym|
        if sym.is_a?(String)
          raise ArgumentError unless sym.length == 1
          @terminals[sym] = [] unless @terminals[sym]
        end
      end

      if enforced_prec
        precedence = @precedence[enforced_prec]
        raise RuntimeError.new("Nothing known about the precedence of '#{enforced_prec}'") unless precedence
        @used_precedence[precedence] = true
      else
        precedence = prec_for_rightmost_terminal(symbols)
      end

      mapname = "#{name.to_s} -> #{symbols.to_s}"
      raise ArgumentError.new("Production #{mapname} is already defined!") if @prodmap[mapname]

      index = @productions.count
      @nonterminals[name] = [] unless @nonterminals[name]

      symbols.each do |sym|
        if @terminals[sym]
          @terminals[sym] << index
        else
          @nonterminals[sym] = [] unless @nonterminals[sym]
          @nonterminals[sym] << index
        end
      end

      p = Production.new(index, name, symbols, precedence, block)

      @productions << p
      @prodmap[mapname] = p

      @prodnames[name] = [] unless @prodnames[name]
      @prodnames[name] << p

      p
    end

    def set_precedence(term, assoc, level)
      raise RuntimeError if @productions != [nil]
      raise ArgumentError if @precedence[term]
      raise ArgumentError unless [:left, :right, :noassoc].include?(assoc)

      @precedence[term] = [assoc, level]
    end

    def set_start(symbol=nil)
      raise RuntimeError.new("No productions defined in #{self}") if @productions.empty?
      symbol = @productions[1].name unless symbol
      raise ArgumentError unless @nonterminals[symbol]
      @productions[0] = Production.new(0, :"S'", [symbol])
      @nonterminals[symbol] << 0
      @start = symbol
    end

    def build_lritems
      @productions.each do |p|
        lastlri = p
        i = 0
        lr_items = []
        while true do
          if i > p.length
            lri = nil
          else
            lri = LRItem.new(p,i)
            lri.lr_after = @prodnames[lri.prod[i+1]] || []
            lri.lr_before = lri.prod[i-1] || nil
          end

          lastlri.lr_next = lri
          break unless lri
          lr_items << lri
          lastlri = lri
          i += 1
        end
        p.lr_items = lr_items
      end
    end

    def compute_first
      return @first unless @first.empty?

      @terminals.keys.each { |t| @first[t] = [t] }
      @first[:'$end'] = [:'$end']
      @nonterminals.keys.each { |n| @first[n] = [] }
      while true
        any_changes = false
        nonterminals.keys.each do |n|
          raise RuntimeError.new("Unefined production '#{n}'") unless @prodnames[n]
          @prodnames[n].each do |p|
            _first(p.prod).each do |f|
              unless @first[n].include?(f)
                @first[n] << f
                any_changes = true
              end
            end
          end
        end
        break unless any_changes
      end

      @first
    end

    def compute_follow(start=nil)
      return @follow unless @follow.empty?

      compute_first if @first.empty?

      @nonterminals.keys.each { |n| @follow[n] = [] }

      start = @productions[1].name unless start

      @follow[start] = [:'$end']

      while true
        didadd = false
        @productions[1..-1].each do |p|
          p.prod.length.times do |i|
            b = p.prod[i]
            next unless @nonterminals.include?(b)

            fst = _first(p.prod[i+1..-1])
            hasempty = false
            fst.each do |f|
              if f != :'<empty>' && !@follow[b].include?(f)
                @follow[b] << f
                didadd = true
              end
              hasempty = true if f == :'<empty>'
            end
            if hasempty || i == p.prod.length - 1
              @follow[p.name].each do |f|
                unless @follow[b].include?(f)
                  @follow[b] << f
                  didadd = true
                end
              end
            end
          end
        end
        break unless didadd
      end

      @follow
    end

    private
    def _first(beta)
      result = []
      should_add_empty = true

      beta.each do |x|
        x_produces_empty = false

        @first[x].each do |f|
          if f == :'<empty>'
            x_produces_empty = true
          else
            result << f unless result.include?(f)
          end
        end

        if x_produces_empty
          next
        else
          should_add_empty = false
          break
        end
      end
      result << :'<empty>' if should_add_empty

      result
    end

    def prec_for_rightmost_terminal(symbols)
      symbols.reverse_each do |sym|
        next unless @terminals[sym]

        return @precedence[sym] || [:right, 0]
      end
      [:right, 0]
    end
  end
end
