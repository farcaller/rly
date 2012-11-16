module Rly
  class LRItem
    attr_accessor :lr_after, :lr_before, :lr_next
    attr_reader :prod, :name, :usyms, :lr_index, :length, :lookaheads, :index

    def initialize(p, n)
      @name = p.name
      @prod = p.prod.dup
      @index = p.index
      @lr_index = n
      @lookaheads = {}
      @prod.insert(n, :'.')
      @length = @prod.length
      @usyms = p.usyms

      @lr_items = []
      @lr_next = nil
    end
    
    def to_s
      if @prod
        "#{@name} -> #{@prod.join(' ')}"
      else
        "#{@name} -> <empty>"
      end
    end

    def inspect
      "#<LRItem #{to_s}>"
    end
  end
end
