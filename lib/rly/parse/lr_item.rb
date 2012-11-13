module Rly
  class LRItem
    attr_accessor :lr_after, :lr_before, :lr_next
    attr_reader :prod

    def initialize(p, n)
      @name = p.name
      @prod = p.prod.dup
      @index = p.index
      @lr_index = n
      @lookaheads = {}
      @prod.insert(n, :'.')
      @len = @prod.length
      @usyms = p.usyms

      @lr_items = []
      @lr_next = nil
    end
    
    
  end
end
