module Rly
  class YaccSymbol
    attr_accessor :type, :value, :lineno, :endlineno, :lexpos, :endlexpos

    def to_s
      @value.to_s
    end

    def inspect
      s = to_s
      "#<YaccSymbol #{@type} '#{s.length > 20 ? s[0..20] + '...' : s}'>"
    end
  end
end
