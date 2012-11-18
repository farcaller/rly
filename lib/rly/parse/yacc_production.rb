module Rly
  class YaccProduction
    attr_accessor :lexer, :parser, :stack, :slice

    def initialize(slice, stack=nil)
      @slice = slice
      @stack = stack
    end
    
  end
end
