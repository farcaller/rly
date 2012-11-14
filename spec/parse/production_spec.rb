require "rly/parse/production"

describe Rly::Production do
  it "has a length same as length of its symbols" do
    p = Rly::Production.new(1, 'test', ['test', '+', 'test'])
    p.length.should == 3
  end

  it "converts to_s as source -> symbols" do
    p = Rly::Production.new(1, 'test', ['test', '+', 'test'])
    p.to_s.should == 'test -> test + test'
  end

  it "builds a list of unique symbols" do
    p = Rly::Production.new(1, 'test', ['test', '+', 'test'])
    p.usyms.should == ['test', '+']
  end
end
