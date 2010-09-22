module Lapaz
  module Routing
    class Route

      class ComponentNotFoundException < StandardError; end
      class ProducerComponentNotAllowed < StandardError; end

      def initialize(*args)
        @chain = []
      end

      def from(component)
        raise ComponentNotFoundException unless component.kind_of?(Lapaz::Component)
        @chain.push(component)
        self
      end

      def filter(klass=nil, &block)
        if klass
          @chain.push(klass)
        else
          @chain.push(Lapaz::Filter::DefaultFilter.new(&block))
        end
        self
      end

      def to(component)
        raise ComponentNotFoundException unless component.kind_of?(Lapaz::Component)
        raise ProducerComponentNotAllowed if component.kind_of?(Lapaz::Producer::Base)
        @chain.push(component)
        self
      end

      def split_entries
        @chain.push(Lapaz::EIP::Splitter.new)
        self
      end

      def run()
        @chain.reverse.each{|component|
          component.run()
          sleep 0.5
        }
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

      def from(component)
        Route.new.from(component)
      end

      def add_route(built_route)
        @routes.push(built_route)
        print '^'
        #puts "added #{built_route.inspect}"
      end
      alias :add :add_route

      def run()
        @routes.collect do |r|
          Thread.new { print '/'; r.run() }
        end.each{|thread| thread.join}
      end

      def self.start()
        router = new
        router.setup_routes
        router.run()
      end
    end
  end

  Lapaz::Router = Lapaz::Routing::Router
end

