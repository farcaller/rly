require "rly/parse/lr_table"
require "rly/version"
require "erb"

module Rly

  class PlyDump
    attr_reader :backlog

    def initialize(grammar)
      @grammar = grammar
      @backlog = ""
      if grammar
        @t = Rly::LRTable.new(grammar)
        @t.parse_table(self)
      end
    end

    def to_s
      fn = File.join(File.dirname(__FILE__), '..', '..', '..', 'assets', 'ply_dump.erb')
      e = ERB.new(open(fn).read)
      e.result(TinyContext.new(g: @grammar, backlog: @backlog, ver: Rly::VERSION).get_binding)
    end

    def self.stub
      PlyDump.new(nil)
    end

    def info(*args)
      s = sprintf(*args)
      @backlog += s + "\n"
    end

    def debug(*args)
      s = sprintf(*args)
      @backlog += s + "\n"
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
