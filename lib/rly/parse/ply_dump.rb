module Rly

  class PlyDump
    def initialize(grammar)
      @grammar = grammar
    end

    def to_s
      fn = File.join(File.dirname(__FILE__), '..', '..', '..', 'assets', 'ply_dump.erb')
      e = ERB.new(open(fn).read)
      e.result(TinyContext.new(g: @grammar).get_binding)
    end

    class TinyContext
      def initialize(ctx)
        @ctx = ctx
      end

      def get_binding
        binding()
      end

      def method_missing(m)
        @ctx[m]
      end
    end
  end

end
