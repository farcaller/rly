require "rly"

module CalcSpecExample
  class CalcLex < Rly::Lex
    literals '=+-*/()'
    ignore " \t\n"

    token :NAME, /[a-zA-Z_][a-zA-Z0-9_]*/

    token :NUMBER, /\d+/ do |t|
      t.value = t.value.to_i
      t
    end

    on_error do |t|
      puts "Illegal character #{t.value}"
      t.lexer.pos += 1
      nil
    end
  end

  class CalcParse < Rly::Yacc
    def names
      @names ||= {}
    end

    precedence :left,  '+', '-'
    precedence :left,  '*', '/'
    precedence :right, :UMINUS

    rule 'statement : NAME "=" expression' do |st, n, _, e|
      self.names[n.value] = e.value
    end

    rule 'statement : expression' do |st, e|
      st.value = e.value
    end

    rule 'expression : expression "+" expression
                     | expression "-" expression
                     | expression "*" expression
                     | expression "/" expression' do |ex, e1, op, e2|
      ex.value = e1.value.send(op.value, e2.value)
    end

    rule 'expression : "-" expression %prec UMINUS' do |ex, _, e|
      ex.value = - e.value
    end

    rule 'expression : "(" expression ")"' do |ex, _, e, _|
      ex.value = e.value
    end

    rule 'expression : NUMBER' do |ex, n|
      ex.value = n.value
    end

    rule 'expression : NAME' do |ex, n|
      nval = self.names[n.value]
      unless nval
        puts "Undefined name '#{n.value}'"
        nval = 0
      end
      ex.value = nval
    end

    # rule_error do |p|
    #   if p
    #     puts "Syntax error at '#{p.value}'"
    #   else
    #     puts "Syntax error at EOF"
    #   end
    # end
  end
end

describe 'Calculator' do
  before :each do
    @calc = CalcSpecExample::CalcParse.new(CalcSpecExample::CalcLex.new)
  end

  it "calculates simple expressions" do
    @calc.parse('2 + 2').should == 4
  end

  it "calculates complex expressions" do
    @calc.parse('(3-1)*6/(3+1)').should == 3
  end

  it "keeps state between parses" do
    @calc.parse('magic = 42')
    @calc.parse('2 * magic').should == 84
  end

  it "follows special case precedence rules" do
    @calc.parse('2 + - 2 + 1').should == 1
  end
end
