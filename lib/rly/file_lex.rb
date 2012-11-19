require "rly/lex"

module Rly
  class FileLex < Lex
    def initialize(fn=nil)
      @inputstack = []
      push_file(fn) if fn
    end
    
    def push_file(fn)
      @inputstack.push([@input, @pos, @filename]) if @filename

      @filename = fn
      @input = open(fn).read
      @pos = 0
    end

    def pop_file
      (@input, @pos, @filename) = @inputstack.pop
    end

    def next
      begin
        tok = super

        if tok
          return tok
        else
          if @inputstack.empty?
            return nil
          else
            pop_file
            redo
          end
        end
      end until tok
    end

    def build_token(type, value)
      tok = LexToken.new(type, value, self, @pos, @lineno)
      tok.location_info[:filename] = @filename
      tok
    end
  end
end
