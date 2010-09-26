module Lapaz
  module Routing
    class Route

      class ComponentNotFoundException < StandardError; end
      class ProducerComponentNotAllowed < StandardError; end

      attr_reader :ctx

      def initialize(opts)
        @addr = opts[:route_internal_addr]
        @route_uuid = ::UUID.generate
        @loop_once = opts[:loop_once] || false
        @opts = opts
        @queue = Queue.new
        @chain = []
      end

      def from(component)
        raise ComponentNotFoundException unless component.kind_of?(Lapaz::Component)
        @chain.push(component)
        self
      end

      def to(cls,opts)
        component = cls.new(@opts.merge(opts))
        raise ComponentNotFoundException unless component.kind_of?(Lapaz::Component)
        raise ProducerComponentNotAllowed if component.kind_of?(Lapaz::Producer)
        @chain.push(component)
        self
      end

      def publish(&blk)
        @queue << blk
      end

      def run()
        @ctx = ZMQ::Context.new(1)
        @pub_sock = ctx.socket(ZMQ::PUB)
        @pub_sock.bind @addr

        @chain.reverse.each{|component|
          component.run(self)
          sleep 0.5
        }
        loop do
          callable = @queue.pop
          callable.call(@pub_sock)
        end
      end

      def inspect
        @chain.inspect
      end
      alias :to_s :inspect
    end

    class Router
      def initialize
        puts "..."
        @routes ||= []
      end

      def setup_routes(&block)
        raise "Subclass this"
      end

      def from(cls,opts)
        Route.new(opts).from(cls.new(opts))
      end

      def add_route(built_route)
        @routes.push(built_route)
        #puts "added #{built_route.inspect}"
      end
      alias :add :add_route

      def run()
        @routes.collect do |r|
          Thread.new { r.run() }
        end.each{|thread| thread.join}
      end

      def self.start
        router = new
        router.setup_routes
        router.run()
      end
    end
  end

  Lapaz::Router = Lapaz::Routing::Router
end

