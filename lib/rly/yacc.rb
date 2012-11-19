require "rly/lex"
require "rly/parse/grammar"
require "rly/parse/yacc_production"
require "rly/parse/yacc_symbol"
require "rly/parse/ply_dump"

module Rly
  class YaccError < RuntimeError; end

  class Yacc
    attr_reader :lex, :grammar, :lr_table

    def initialize(lex=nil)
      raise ArgumentError.new("No lexer available") if lex == nil && self.class.lexer_class == nil
      @lex = lex || self.class.lexer_class.new

      @grammar = grammar
    end

    def inspect
      "#<#{self.class} ...>"
    end

    def parse(input=nil, trace=false)
      @trace = trace

      lookahead = nil
      lookaheadstack = []
      actions = @lr_table.lr_action
      goto = @lr_table.lr_goto
      prod = @lr_table.lr_productions
      pslice = YaccProduction.new(nil)
      errorcount = 0

      # Set up the lexer and parser objects on pslice
      pslice.lexer = @lex
      pslice.parser = self

      # If input was supplied, pass to lexer
      @lex.input(input) if input

      # Set up the state and symbol stacks
      @statestack = []
      @symstack = []

      pslice.stack = @symstack
      errtoken = nil

      # The start state is assumed to be (0,$end)
      @statestack.push(0)
      sym = YaccSymbol.new
      sym.type = :"$end"
      @symstack.push(sym)
      state = 0

      while true
        # Get the next symbol on the input.  If a lookahead symbol
        # is already set, we just use that. Otherwise, we'll pull
        # the next token off of the lookaheadstack or from the lexer

        puts "State  : #{state}" if @trace

        unless lookahead
          if lookaheadstack.empty?
            lookahead = @lex.next
          else
            lookahead = lookaheadstack.pop
          end
          unless lookahead
            lookahead = YaccSymbol.new()
            lookahead.type = :"$end"
          end
        end

        puts "Stack  : #{(@symstack[1..-1].map{|s|s.type}.join(' ') + ' ' + lookahead.inspect).lstrip}" if @trace

        # Check the action table
        ltype = lookahead.type
        t = actions[state][ltype]

        if t
          if t > 0
            # shift a symbol on the stack
            @statestack.push(t)
            state = t

            puts "Action : Shift and goto state #{t}" if @trace
            
            @symstack.push(lookahead)
            lookahead = nil

            # Decrease error count on successful shift
            errorcount -= 1 if errorcount > 0
            next
          end

          if t < 0
            # reduce a symbol on the stack, emit a production
            p = prod[-t]
            pname = p.name
            plen  = p.length

            # Get production function
            sym = YaccSymbol.new()
            sym.type = pname
            sym.value = nil

            if @trace
              if plen
                puts "Action : Reduce rule [#{p}] with [#{@symstack[-plen..@symstack.length].map{|s|s.inspect}.join(', ')}] and goto state #{-t}"
              else
                puts "Action : Reduce rule [#{p}] with [] and goto state #{-t}"
              end
            end

            if plen
              targ = @symstack.pop(plen)
              targ.insert(0, sym)

              # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
              # The code enclosed in this section is duplicated
              # below as a performance optimization.  Make sure
              # changes get made in both locations.

              pslice.slice = targ
              
              begin
                # Call the grammar rule with our special slice object
                @statestack.pop(plen)
                instance_exec(*targ, &p.block)

                puts "Result : #{targ[0].inspect}" if @trace

                @symstack.push(sym)
                state = goto[@statestack[-1]][pname]
                @statestack.push(state)
              rescue YaccError
                # If an error was set. Enter error recovery state
                lookaheadstack.push(lookahead)
                @symstack.pop # FIXME: this is definitely broken
                @statestack.pop
                state = @statestack[-1]
                sym.type = :error
                lookahead = sym
                errorcount = self.class.error_count
                @errorok = false
              end
              next
              # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            else
              targ = [ sym ]

              # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
              # The code enclosed in this section is duplicated
              # below as a performance optimization.  Make sure
              # changes get made in both locations.

              pslice.slice = targ
              
              begin
                # Call the grammar rule with our special slice object
                @statestack.pop(plen)
                pslice[0] = instance_exec(*pslice, &p.block)

                puts "Result : #{targ[0].value}" if @trace

                @symstack.push(sym)
                state = goto[@statestack[-1]][pname]
                @statestack.push(state)
              rescue
                # If an error was set. Enter error recovery state
                lookaheadstack.push(lookahead)
                @symstack.pop # FIXME: this is definitely broken
                @statestack.pop
                state = @statestack[-1]
                sym.type = :error
                lookahead = sym
                errorcount = error_count
                @errorok = false
              end
              next
              # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            end
          end

          if t == 0
            n = @symstack[-1]
            result = n.value

            puts "Done   : Returning #{result}" if @trace

            return result
          end
        end

        if t == nil
          # We have some kind of parsing error here.  To handle
          # this, we are going to push the current token onto
          # the tokenstack and replace it with an 'error' token.
          # If there are any synchronization rules, they may
          # catch it.
          #
          # In addition to pushing the error token, we call call
          # the user defined p_error() function if this is the
          # first syntax error.  This function is only called if
          # errorcount == 0.
          if errorcount == 0 || @errorok == true
            errorcount = self.class.error_count
            @errorok = false
            errtoken = lookahead
            errtoken = nil if errtoken.type == :"$end"

            if self.class.error_handler
              tok = self.instance_exec(errtoken, &self.class.error_handler)

              if @errorok
                # User must have done some kind of panic
                # mode recovery on their own.  The
                # returned token is the next lookahead
                lookahead = tok
                errtoken = nil
                next
              end
            else
              if errtoken
                location_info = lookahead.location_info
                puts "Fail   : Syntax error at #{location_info}, token='#{errtoken}'" if @trace
              else
                puts "Fail   : Parse error in input. EOF" if @trace
                return nil
              end
            end
          else
            errorcount = self.class.error_count
          end

          # case 1:  the @statestack only has 1 entry on it.  If we're in this state, the
          # entire parse has been rolled back and we're completely hosed.   The token is
          # discarded and we just keep going.

          if @statestack.length <= 1 and lookahead.type != :"$end"
            lookahead = nil
            errtoken = nil
            state = 0
            # Nuke the pushback stack
            lookaheadstack = []
            next
          end

          # case 2: the @statestack has a couple of entries on it, but we're
          # at the end of the file. nuke the top entry and generate an error token

          # Start nuking entries on the stack
          if lookahead.type == :"$end"
            # Whoa. We're really hosed here. Bail out
            return nil
          end

          if lookahead.type != :error
            sym = @symstack[-1]
            if sym.type == :error
              # Hmmm. Error is on top of stack, we'll just nuke input
              # symbol and continue
              lookahead = nil
              next
            end
            t = YaccSymbol.new
            t.type = :error
            # if hasattr(lookahead,"lineno"):
            #    t.lineno = lookahead.lineno
            t.value = lookahead
            lookaheadstack.push(lookahead)
            lookahead = t
          else
            @symstack.pop
            @statestack.pop
            state = @statestack[-1]       # Potential bug fix
          end

          next
        end

        # Call an error function here
        raise RuntimeError.new("yacc: internal parser error!!!")
      end
    end

    protected
    def grammar
      return @grammar if @grammar

      @grammar = Grammar.new(@lex.class.terminals)

      self.class.prec_rules.each do |assoc, terms, i|
        terms.each do |term|
          @grammar.set_precedence(term, assoc, i)
        end
      end

      self.class.parsed_rules.each do |pname, p, prec, block|
        @grammar.add_production(pname, p, prec, &block)
      end

      @grammar.set_start

      @grammar.build_lritems

      if self.class.store_grammar_def
        d = PlyDump.new(@grammar)
        gdef = d.to_s
        open(self.class.store_grammar_def, 'w') { |f| f.write(gdef) }
      end

      @lr_table = LRTable.new(@grammar)

      @lr_table.parse_table

      @grammar
    end

    class << self
      attr_accessor :rules, :grammar, :lexer_class, :prec_rules, :error_handler, :store_grammar_def

      def store_grammar(fn)
        @store_grammar_def = fn
      end

      def rule(desc, &block)
        self.rules << [desc, block]
        nil
      end

      def lexer(&block)
        @lexer_class = Class.new(Lex, &block)
        nil
      end

      def rules
        @rules ||= []
      end

      def precedence(*prec)
        assoc = prec.shift
        count = self.prec_rules.length + 1
        self.prec_rules << [assoc, prec, count]
        nil
      end

      def prec_rules
        @prec_rules ||= []
      end

      def error_count
        3
      end

      def on_error(lambda)
        @error_handler = lambda
      end

      def parsed_rules
        return @parsed_rules if @parsed_rules

        @parsed_rules = []
        rp = RuleParser.new
        self.rules.each do |desc, block|
          rules = rp.parse(desc)
          raise RuntimeError.new("Failed to parse rules: #{desc}") unless rules
          rules.each do |(pname, p, prec)|
            @parsed_rules << [pname, p, prec, block]
          end
        end
        @parsed_rules
      end
    end
  end
end
