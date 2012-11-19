require "rly/lex_token"

module Rly

  # Exception, which is returned on unhandled lexing errors.
  class LexError < Exception; end

  # Base class for your lexer.
  #
  # Generally, you define a new lexer by subclassing Rly::Lex. Your code should
  # use methods {.token}, {.ignore}, {.literals}, {.on_error} to make the lexer
  # configuration (check the methods documentation for details).
  #
  # Once you got your lexer configured, you can create its instances passing a
  # String to be tokenized. You can then use {#next} method to get tokens. If you
  # have more string to tokenize, you can append it to input buffer at any time with
  # {#input}.
  class Lex

    # Tracks the current line number for generated tokens
    #
    # *lineno*'s value should be increased manually. Check the example for a demo
    # rule.
    #
    # @api semipublic
    # @return [Fixnum] current line number
    #
    # @example
    #   token /\n+/ do |t| t.lexer.lineno = t.value.count("\n"); t end
    attr_accessor :lineno

    # Tracks the current position in the input string
    #
    # Genreally, it should only be used to skip a few characters in the error hander.
    #
    # @api semipublic
    # @return [Fixnum] index of a starting character for current token
    #
    # @example
    #   on_error do |t|
    #     t.lexer.pos += 1
    #     nil # skip the bad character
    #   end
    attr_accessor :pos

    # Creates a new lexer instance for given input
    #
    # @api public
    # @param input [String] a string to be tokenized
    # @example
    #   class MyLexer < Rly::Lex
    #     ignore " "
    #     token :LOWERS, /[a-z]+/
    #     token :UPPERS, /[A-Z]+/
    #   end
    #
    #   lex = MyLexer.new("hello WORLD")
    #   t = lex.next
    #   puts "#{tok.type} -> #{tok.value}" #=> "LOWERS -> hello"
    #   t = lex.next
    #   puts "#{tok.type} -> #{tok.value}" #=> "UPPERS -> WORLD"
    #   t = lex.next # => nil
    def initialize(input="")
      @input = input
      @pos = 0
      @lineno = 0
    end

    def inspect
      "#<#{self.class} pos=#{@pos} len=#{@input.length} lineno=#{@lineno}>"
    end

    # Appends string to input buffer
    #
    # The given string is appended to input buffer, further {#next} calls will
    # tokenize it as usual.
    #
    # @api public
    #
    # @example
    #   lex = MyLexer.new("hello")
    #
    #   t = lex.next
    #   puts "#{tok.type} -> #{tok.value}" #=> "LOWERS -> hello"
    #   t = lex.next # => nil
    #   lex.input("WORLD")
    #   t = lex.next
    #   puts "#{tok.type} -> #{tok.value}" #=> "UPPERS -> WORLD"
    #   t = lex.next # => nil
    def input(input)
      @input << input
      nil
    end

    # Processes the next token in input
    #
    # This is the main interface to lexer. It returns next available token or **nil**
    # if there are no more tokens available in the input string.
    #
    # {#each} Raises {LexError} if the input cannot be processed. This happens if
    # there were no matches by 'token' rules and no matches by 'literals' rule.
    # If the {.on_error} handler is not set, the exception will be raised immediately,
    # however, if the handler is set, the eception will be raised only if the {#pos}
    # after returning from error handler is still unchanged.
    #
    # @api public
    # @raise [LexError] if the input cannot be processed
    # @return [LexToken] if the next chunk of input was processed successfully
    # @return [nil] if there are no more tokens available in input
    #
    # @example
    #   lex = MyLexer.new("hello WORLD")
    #
    #   t = lex.next
    #   puts "#{tok.type} -> #{tok.value}" #=> "LOWERS -> hello"
    #   t = lex.next
    #   puts "#{tok.type} -> #{tok.value}" #=> "UPPERS -> WORLD"
    #   t = lex.next # => nil
    def next
      while @pos < @input.length
        if self.class.ignores_list[@input[@pos]]
          ignore_symbol
          next
        end

        m = self.class.token_regexps.match(@input[@pos..-1])

        if m && ! m[0].empty?
          val = nil
          type = nil
          resolved_type = nil
          m.names.each do |n|
            if m[n]
              type = n.to_sym
              resolved_type = (n.start_with?('__anonymous_') ? nil : type)
              val = m[n]
              break
            end
          end

          if type
            tok = build_token(resolved_type, val)
            @pos += m.end(0)
            tok = self.class.callables[type].call(tok) if self.class.callables[type]

            if tok && tok.type
              return tok
            else
              next
            end
          end
        end
        
        if self.class.literals_list[@input[@pos]]
          tok = build_token(@input[@pos], @input[@pos])
          matched = true
          @pos += 1
          return tok
        end

        if self.class.error_hander
          pos = @pos
          tok = build_token(:error, @input[@pos])
          tok = self.class.error_hander.call(tok)
          if pos == @pos
            raise LexError.new("Illegal character '#{@input[@pos]}' at index #{@pos}")
          else
            return tok if tok && tok.type
          end
        else
          raise LexError.new("Illegal character '#{@input[@pos]}' at index #{@pos}")
        end

      end
      return nil
    end

    def build_token(type, value)
      LexToken.new(type, value, self, @pos, @lineno)
    end

    def ignore_symbol
      @pos += 1
    end

    class << self
      def terminals
        self.tokens.map { |t,r,b| t }.compact + self.literals_list.chars.to_a + self.metatokens_list
      end

      def callables
        @callables ||= {}
      end

      def token_regexps
        return @token_regexps if @token_regexps

        collector = []
        self.tokens.each do |name, rx, block|
          name = "__anonymous_#{block.hash}".to_sym unless name

          self.callables[name] = block
          
          rxs = rx.to_s
          named_rxs = "\\A(?<#{name}>#{rxs})"

          collector << named_rxs
        end

        rxss = collector.join('|')
        @token_regexps = Regexp.new(rxss)
      end

      def metatokens_list
        @metatokens_list ||= []
      end

      def metatokens(*args)
        @metatokens_list = args
      end

      # Returns the list of registered tokens
      #
      # @api private
      # @visibility protected
      # @return [Array] array of [type, regex, block] triples
      def tokens
        @tokens ||= []
      end

      # Returns the list of registered literals
      #
      # @api private
      # @visibility protected
      # @return [String] registered literals
      def literals_list
        @literals ||= ""
      end

      # Returns the list of registered ignorables
      #
      # @api private
      # @visibility protected
      # @return [String] registered ignorables
      def ignores_list
        @ignores ||= ""
      end

      # Returns the registered error handler, if any
      #
      # @api private
      # @visibility protected
      # @return [Proc] registered error handler
      def error_hander
        @error_block
      end

      private
      # @!group DSL Class Methods
      # Adds a token definition to a class
      #
      # This method adds a token definition to be lated used to tokenize input.
      # It can be used to register normal tokens, and also functional tokens (the
      # latter ones are processed as usual but are not being returned).
      #
      # @!visibility public
      # @api public
      # @param type [Symbol] token type. It should be an all-caps symbol by convention
      # @param regex [Regexp] a regular expression to match the token
      #
      # @yieldparam tok [LexToken] a new token instance for processed input
      # @yieldreturn [LexToken] the same or modified token instance. Return nil
      #              to ignore the input
      # @see .literals
      # @see .ignores
      # @example
      #   class MyLexer < Rly::Lex
      #     token :LOWERS, /[a-z]+/   # this would match LOWERS on 1+ lowercase letters
      #
      #     token :INT, /\d+/ do |t|  # this would match on integers
      #       t.value = t.value.to_i  # additionally the value is converted to Fixnum
      #       t                       # the updated token is returned
      #     end
      #
      #     token /\n/ do |t|        # this would match on newlines
      #       t.lexer.lineno += 1    # the block will be executed on match, but
      #     end                      # no token will be returned (as name is not specified)
      #
      #   end
      def token(*args, &block)
        if args.length == 2
          self.tokens << [args[0], args[1], block]
        elsif args.length == 1
          self.tokens << [nil, args[0], block]
        else
          raise ArgumentError
        end
        nil
      end

      # Specifies a list of one-char literals
      #
      # Literals may be used in the case when you have several one-character tokens
      # and you don't want to define them one by one using {.token} method.
      #
      # @!visibility public
      # @api public
      # @param lit [String] the list of literals
      # @see .token
      # @example
      #   class MyLexer < Rly::Lex
      #     literals "+-/*"
      #   end
      #
      #   lex = MyLexer.new("+-")
      #   lex.each do |tok|
      #     puts "#{tok.type} -> #{tok.value}" #=> "+ -> +"
      #                                        #=> "- -> -"
      #   end
      def literals(lit)
        @literals = lit
        nil
      end

      # Specifies a list of one-char symbols to be ignored in input
      #
      # This method allows to skip over formatting symbols (like tabs and spaces) quickly.
      #
      # @!visibility public
      # @api public
      # @param ign [String] the list of ignored symbols
      # @see .token
      # @example
      #   class MyLexer < Rly::Lex
      #     literals "+-"
      #     token :INT, /\d+/
      #     ignore " \t"
      #   end
      #
      #   lex = MyLexer.new("2 + 2")
      #   lex.each do |tok|
      #     puts "#{tok.type} -> #{tok.value}" #=> "INT -> 2"
      #                                        #=> "+ -> +"
      #                                        #=> "INT -> 2"
      #   end
      def ignore(ign)
        @ignores = ign
        nil
      end

      # Specifies a block that should be called on error
      #
      # In case of lexing error the lexer first tries to fix it by providing a
      # chance for developer to look on the failing character. If this block is
      # not provided, the lexing error always results in {LexError}.
      #
      # You must increment the lexer's {#pos} as part of the action. You may also
      # return a new {LexToken} or nil to skip the input
      #
      # @!visibility public
      # @api public
      # @see .token
      # @example
      #   class MyLexer < Rly::Lex
      #     token :INT, /\d+/
      #     on_error do |tok|
      #       tok.lexer.pos += 1 # just skip the offending character
      #     end
      #   end
      #
      #   lex = MyLexer.new("123qwe")
      #   lex.each do |tok|
      #     puts "#{tok.type} -> #{tok.value}" #=> "INT -> 123"
      #   end
      def on_error(&block)
        @error_block = block
        nil
      end
    end
  end
end
