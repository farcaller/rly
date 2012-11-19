module Rly
  class Production
    attr_reader :index, :name, :prod, :precedence, :block, :usyms, :line
    attr_accessor :lr_items, :lr_next, :lr0_added, :reduced

    # FIXME line!!!
    def initialize(index, name, prod, precedence=[:right, 0], block=nil)
      @index = index
      @name = name
      @prod = prod
      @precedence = precedence
      @block = block

      @usyms = []
      prod.each { |sym| @usyms << sym unless @usyms.include?(sym) }
    end

    def to_s
      "#{name} -> #{@prod.map { |s| s.to_s }.join(' ')}"
    end

    def inspect
      "#<Production #{to_s}>"
    end

    def length
      @prod.length
    end

    def line
      @line ||= 0
    end

    def lr0_added
      @lr0_added ||= 0
    end

    def reduced
      @reduced ||= 0
    end
  end
end
