require "rly/lex"
require "rly/parse/grammar"

module Rly
  class Parse
    attr_reader :lex, :grammar, :lr_table

    def initialize(lex=nil)
      raise ArgumentError.new("No lexer available") if lex == nil && self.class.lexer_class == nil
      @lex = lex || self.class.lexer_class.new

      #@grammar = self.class.grammar
    end


    class << self
      attr_accessor :rules, :grammar, :lexer_class

      def rule(desc, &block)
        self.rules << [desc, block]
      end

      def lexer(&block)
        @lexer_class = Class.new(Lex, &block)
      end

      def rules
        @rules ||= []
      end

      def grammar
        return @grammar if @grammar

        @grammar = Grammar.new(self.lexer_class.terminals)

        # FIXME ...
      end
    end
  end
end
