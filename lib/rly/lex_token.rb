module Rly

  class LexToken
    attr_accessor :value
    attr_reader :type, :lexer

    def initialize(type, value, lexer)
      @type = type
      @value = value
      @lexer = lexer
    end
  end
end
