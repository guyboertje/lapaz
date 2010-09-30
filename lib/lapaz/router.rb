module Lapaz
  module Routing
    class Route

      ComponentNotFoundException = Class.new(StandardError)
      ProducerComponentNotAllowed = Class.new(StandardError)

      attr_reader :ctx, :name, :router, :named_steps

      def initialize(opts,router)
        @addr,@name = opts.values_at(:route_internal_addr,:route_name)
        @route_uuid = ::UUID.generate
        @loop_once = opts[:loop_once] || false
        @opts = opts
        @queue = Queue.new
        @chain = []
        @router = router
        @named_steps = {}
      end

      def from(component)
        raise ComponentNotFoundException unless component.kind_of?(Lapaz::Component)
        @chain.push(component)
        @named_steps[component.name] = component.seq_id if component.name
        self
      end

      def to(cls,opts)
        component = cls.new(@opts.merge(opts))
        raise ComponentNotFoundException unless component.kind_of?(Lapaz::Component)
        raise ProducerComponentNotAllowed if component.kind_of?(Lapaz::Producer)
        @chain.push(component)
        @named_steps[component.name] = component.seq_id if component.name
        self
      end

      def publish(q_object)
        #puts q_object.inspect
        route_name = q_object.route
        if route_name != self.name
          ret = @router.publish(q_object)
        else
          return "In route: #{self.name}, cannot find a step named: #{q_object.name}" if q_object.named? && !@named_steps.has_key?(q_object.name)
          if q_object.named?
            q_object.seq_id = @named_steps[q_object.name]
          end
          @queue << q_object
          ret = ''
        end
        ret
      end

      def run()
        @ctx = ZMQ::Context.new(1)
        @pub_sock = ctx.socket(ZMQ::PUB)
        @pub_sock.bind @addr
        @chain.reverse.each{|component|
          component.run(self)
          sleep 0.2
        }
        loop do
          q_object = @queue.pop
          @pub_sock.send_string(q_object.topic, ZMQ::SNDMORE) #TOPIC
          @pub_sock.send_string(q_object.msg) #BODY
          puts "->>#{q_object.topic}"
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
        @routes ||= {}
      end

      def publish(q_object)
        route_name = q_object.route
        return "Cannot find a route named: #{route_name}" unless @routes.has_key?(route_name)
        @routes[route_name].publish(q_object)
        ''
      end

      def setup_routes(&block)
        raise "Subclass this"
      end

      def from(cls,opts)
        Route.new(opts, self).from(cls.new(opts))
      end

      def add_route(built_route)
        @routes[built_route.name] = built_route
        #puts "added #{built_route.inspect}"
      end
      alias :add :add_route

      def run()
        #puts @routes.inspect
        @routes.values.collect do |r|
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



