require "rly"
require "rly/helpers"

describe "Rly::Lex Helpers" do
  it "has a helper to use a common whitespace ignore pattern" do
    testLexer = Class.new(Rly::Lex) do
      ignore_spaces_and_tabs
    end

    expect { testLexer.new(" \t \t").next }.not_to raise_exception
  end

  it "has a helper to parse numeric tokens" do
    testLexer = Class.new(Rly::Lex) do
      lex_number_tokens
    end

    tok = testLexer.new("123").next
    tok.type.should == :NUMBER
    tok.value.should == 123
  end

  it "has a helper to parse double-quoted string tokens" do
    testLexer = Class.new(Rly::Lex) do
      lex_double_quoted_string_tokens
    end

    tok = testLexer.new('"a test"').next
    tok.type.should == :STRING
    tok.value.should == 'a test'
  end
end
