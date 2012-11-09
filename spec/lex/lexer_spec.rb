require "rly"

describe Rly::Lex do
  context "Simple Lexer" do
    testLexer = Class.new(Rly::Lex) do
      token :FIRST, /[a-z]+/
      token :SECOND, /[A-Z]+/
    end

    it "should have a list of defined tokens" do
      testLexer.tokens.map { |t, r, b| t }.should == [:FIRST, :SECOND]
    end

    it "should output tokens one by one" do
      test = 'qweASDzxc'
      l = testLexer.new(test).to_enum

      tok = l.next
      tok.type.should == :FIRST
      tok.value.should == 'qwe'

      tok = l.next
      tok.type.should == :SECOND
      tok.value.should == 'ASD'

      tok = l.next
      tok.type.should == :FIRST
      tok.value.should == 'zxc'

      expect { l.next } .to raise_error(StopIteration)
    end
  end

  context "Literals Lexer" do
    testLexer = Class.new(Rly::Lex) do
      literals "+-*/"
    end
    
    it "should output literal tokens" do
      test = '++--'
      l = testLexer.new(test).to_enum

      l.next.value.should == '+'
      l.next.value.should == '+'
      l.next.value.should == '-'
      l.next.value.should == '-'
    end
  end

  context "Ignores Lexer" do
    testLexer = Class.new(Rly::Lex) do
      ignore " \t"
    end
    
    it "should honour ignores list" do
      test = "     \t\t  \t    \t"
      l = testLexer.new(test).to_enum

      expect { l.next } .to raise_error(StopIteration)
    end
  end

  context "Block-based Token Lexer" do
    testLexer = Class.new(Rly::Lex) do
      token :TEST, /\d+/ do |t|
        t.value = t.value.to_i
        t
      end
    end
    
    it "calls a block to further process a token" do
      test = "42"
      l = testLexer.new(test).to_enum

      l.next.value == 42
    end
  end

  context "Non-outputtable tokens Lexer" do
    testLexer = Class.new(Rly::Lex) do
      token /\n+/ do |t| t.lexer.lineno = t.value.count("\n"); t end
    end
    
    it "process but don't output tokens without a name" do
      test = "\n\n\n"
      l = testLexer.new(test)

      expect { l.to_enum.next } .to raise_error(StopIteration)

      l.lineno.should == 3
    end
  end

  context "Error handling" do
    it "raises an error, if there are no suitable tokens" do
      testLexer = Class.new(Rly::Lex) do
        token :NUM, /\d+/
      end
      l = testLexer.new("test")

      expect { l.to_enum.next } .to raise_error(Rly::LexError)
    end

    it "raises an error, if there is no possible tokens defined" do
      testLexer = Class.new(Rly::Lex) do ; end
      l = testLexer.new("test")

      expect { l.to_enum.next } .to raise_error(Rly::LexError)
    end

    it "calls an error function if it is available, which returns a fixed token" do
      testLexer = Class.new(Rly::Lex) do
        token :NUM, /\d+/
        on_error do |t|
          t.value = "BAD #{t.value}"
          t.lexer.pos += 1
          t
        end
      end
      l = testLexer.new("test")

      tok = l.to_enum.next
      tok.value.should == "BAD t"
      tok.type.should == :error

      tok = l.to_enum.next
      tok.value.should == "BAD e"
      tok.type.should == :error
    end

    it "calls an error function if it is available, which can skip a token" do
      testLexer = Class.new(Rly::Lex) do
        token :NUM, /\d+/
        on_error do |t|
          t.lexer.pos += 1
          nil
        end
      end
      l = testLexer.new("test1")

      l.to_enum.next.value.should == '1'
    end
  end
end
