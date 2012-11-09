require "rly/lex_token"

module Rly

  class LexError < Exception; end

  class Lex
    include Enumerable

    attr_accessor :lineno, :pos

    def initialize(input="")
      @input = input
      @pos = 0
      @lineno = 0
    end

    def each
      while @pos < @input.length
        if self.class.ignores_list[@input[@pos]]
          @pos += 1
          next
        end

        matched = false
        self.class.tokens.each do |type, rule, block|
          m = rule.match(@input, @pos)
          next unless m

          tok = LexToken.new(type, m[0], self)

          matched = true

          tok = block.call(tok) if block
          yield tok if tok.type

          @pos = m.end(0)
        end

        unless matched
          if self.class.literals_list[@input[@pos]]
            tok = LexToken.new(@input[@pos], @input[@pos], self)

            matched = true
            yield tok
            @pos += 1
          end
        end

        unless matched
          if self.class.error_hander
            pos = @pos
            tok = LexToken.new(:error, @input[@pos], self)
            tok = self.class.error_hander.call(tok)
            if pos == @pos
              raise LexError.new("Illegal character '#{@input[@pos]}' at index #{@pos}")
            else
              yield tok if tok && tok.type
            end
          else
            raise LexError.new("Illegal character '#{@input[@pos]}' at index #{@pos}")
          end
        end
      end
    end

    class << self
      def tokens
        @tokens ||= []
      end

      def literals_list
        @literals ||= ""
      end

      def ignores_list
        @ignores ||= ""
      end

      def error_hander
        @error_block
      end

      private
      def token(*args, &block)
        if args.length == 2
          self.tokens << [args[0], args[1], block]
        elsif args.length == 1
          self.tokens << [nil, args[0], block]
        else
          raise ArgumentError
        end
      end

      def literals(lit)
        @literals = lit
      end

      def ignore(ign)
        @ignores = ign
      end

      def on_error(&block)
        @error_block = block
      end
    end
  end
end
