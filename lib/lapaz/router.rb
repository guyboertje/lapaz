module Lapaz
  module Routing
    class Route

      ComponentNotFoundException = Class.new(StandardError)
      ProducerComponentNotAllowed = Class.new(StandardError)

      include Blockenspiel::DSL

      attr_reader :name, :app, :named_steps

      def initialize(opts,app)
        @name = opts[:route_name]
        @route_uuid = ::UUID.generate
        @loop_once = opts[:loop_once] || false
        @opts = opts
        @chain = []
        @app = app
        @named_steps = {}
      end

      dsl_methods false

      def describe
        ret = @chain.map do |comp|
          comp.describe
        end.flatten
        ret
      end

      def publish(sock,q_object)
        raise "In route: #{self.name}, cannot find a step named: #{q_object.name}" if q_object.named? && !@named_steps.has_key?(q_object.name)
        if q_object.named?
          q_object.seq_id = @named_steps[q_object.name]
        end
        sock.send_string(q_object.topic, ZMQ::SNDMORE) #TOPIC
        sock.send_string(q_object.msg) #BODY
        #puts "->>#{q_object.topic}"
      end

      def run()
        @chain.reverse.each{|component|
          component.run(app)
          sleep 0.2
        }
      end

      def inspect
        @chain.inspect
      end

      alias :to_s :inspect

      dsl_methods true

      def from(cls,opts)
        component = cls.new(@opts.merge(opts))
        raise ComponentNotFoundException unless component.kind_of?(Lapaz::Component)
        @chain.push(component)
        @named_steps[component.name] = component.seq_id if component.name
      end

      def to(cls,opts)
        component = cls.new(@opts.merge(opts))
        raise ComponentNotFoundException unless component.kind_of?(Lapaz::Component)
        raise ProducerComponentNotAllowed if component.producer?
        @chain.push(component)
        @named_steps[component.name] = component.seq_id if component.name
      end
    end

    class Router
      include Blockenspiel::DSL
      attr_reader :path_handler, :name
      def initialize(name)
        @name = name
        @routes ||= {}
        @path_handler = PathHandler.new
        @queue = Queue.new
        puts "... #{name} ..."
      end

      dsl_methods false

      def enqueue(q_object)
        #puts q_object.inspect
        @queue << q_object
      end

      def services
        srvs = @routes.values.map do |r|
          r.describe
        end.flatten.compact
        {:app => @name, :routes => srvs}
      end

      def publish(q_object)
        route_name = q_object.route
        raise "Cannot find a route named: #{route_name}" unless @routes.has_key?(route_name)
        @routes[route_name].publish(@pub_sock, q_object)
      end

      def run()

        @pub_sock = lapazcfg.app.ctx.socket(ZMQ::PUB)
        @pub_sock.bind lapazcfg.app.endpt

        @routes.values.collect do |r|
          Thread.new { r.run() }
        end.each{|thread| thread.join}

        loop do
          publish @queue.pop
        end
      end

      def self.application(name,&block)
        app = new(name)
        Blockenspiel.invoke(block, app)
        app
      end

      dsl_methods true

      def route opts, &block
        name = opts[:route_name]
        @routes[name] = Route.new(opts,self)
        Blockenspiel.invoke(block, @routes[name])
      end

      def url_handlers &block
        Blockenspiel.invoke(block, @path_handler)
      end

    end
  end

  Lapaz::Router = Lapaz::Routing::Router
end



