require "rly"

describe Rly::Lex do
  context "Basic lexer" do
    testLexer = Class.new(Rly::Lex) do
      token :FIRST, /[a-z]+/
      token :SECOND, /[A-Z]+/
    end

    it "has a list of defined tokens" do
      testLexer.tokens.map { |t, r, b| t }.should == [:FIRST, :SECOND]
    end

    it "outputs tokens one by one" do
      test = 'qweASDzxc'
      l = testLexer.new(test)

      tok = l.next
      tok.type.should == :FIRST
      tok.value.should == 'qwe'

      tok = l.next
      tok.type.should == :SECOND
      tok.value.should == 'ASD'

      tok = l.next
      tok.type.should == :FIRST
      tok.value.should == 'zxc'

      l.next.should be_nil
    end

    it "provides tokens in terminals list" do
      testLexer.terminals.should == [:FIRST, :SECOND]
    end
  end

  context "Lexer with literals defined" do
    testLexer = Class.new(Rly::Lex) do
      literals "+-*/"
    end
    
    it "outputs literal tokens" do
      test = '++--'
      l = testLexer.new(test)

      l.next.value.should == '+'
      l.next.value.should == '+'
      l.next.value.should == '-'
      l.next.value.should == '-'
    end

    it "provides literals in terminals list" do
      testLexer.terminals.should == ['+', '-', '*', '/']
    end
  end

  context "Lexer with ignores defined" do
    testLexer = Class.new(Rly::Lex) do
      ignore " \t"
    end
    
    it "honours ignores list" do
      test = "     \t\t  \t    \t"
      l = testLexer.new(test)

      l.next.should be_nil
    end
  end

  context "Lexer with token that has a block given" do
    testLexer = Class.new(Rly::Lex) do
      token :TEST, /\d+/ do |t|
        t.value = t.value.to_i
        t
      end
    end
    
    it "calls a block to further process a token" do
      test = "42"
      l = testLexer.new(test)

      l.next.value.should == 42
    end
  end

  context "Lexer with unnamed token and block given" do
    testLexer = Class.new(Rly::Lex) do
      token /\n+/ do |t| t.lexer.lineno = t.value.count("\n"); t end
    end
    
    it "processes but don't output tokens without a name" do
      test = "\n\n\n"
      l = testLexer.new(test)

      l.next.should be_nil

      l.lineno.should == 3
    end
  end

  context "Lexer with no error handler" do
    it "raises an error, if there are no suitable tokens" do
      testLexer = Class.new(Rly::Lex) do
        token :NUM, /\d+/
      end
      l = testLexer.new("test")

      expect { l.next } .to raise_error(Rly::LexError)
    end

    it "raises an error, if there is no possible tokens defined" do
      testLexer = Class.new(Rly::Lex) do ; end
      l = testLexer.new("test")

      expect { l.next } .to raise_error(Rly::LexError)
    end
  end

  context "Lexer with error handler" do
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

      tok = l.next
      tok.value.should == "BAD t"
      tok.type.should == :error

      tok = l.next
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

      l.next.value.should == '1'
    end
  end

  it "doesn't try to skip chars over" do
    testLexer = Class.new(Rly::Lex) do
        token :NUM, /\d+/
        literals ","
      end
      l = testLexer.new(",10")

      l.next.type.should == ','
      l.next.type.should == :NUM
  end
end
