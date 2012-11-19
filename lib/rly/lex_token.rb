module Rly

  class LexToken
    attr_accessor :value, :type, :location_info
    attr_reader :lexer

    def initialize(type, value, lexer, pos=0, lineno=0, filename=nil)
      @type = type
      @value = value
      @lexer = lexer
      @location_info = { pos: pos, lineno: lineno, filename: filename }
    end

    def to_s
      @value.to_s
    end

    def inspect
      "#<LexToken #{@type} '#{@value}'>"
    end
  end
end
