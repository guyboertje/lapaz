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

      def describe(external_only=false)
        ret = @chain.map do |comp|
          comp.describe(external_only)
        end.flatten
        ret
      end

      def publish(trans,q_object)
        raise "In route: #{self.name}, cannot find a step named: #{q_object.name}" if q_object.named? && !@named_steps.has_key?(q_object.name)
        if q_object.named?
          q_object.seq_id = @named_steps[q_object.name]
        end
        topic = lapazcfg.app.topic_base + q_object.topic
        trans.send(topic, q_object.msg)
      end

      def run()
        @chain.reverse.each{|component|
          component.run(app)
          sleep 0.25
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
    class ExtRoutesCache
      def initialize()
        @cache = {}
      end
      def add(services)
        uuid,routes = services.values_at(:app_id,:routes)
        @cache[uuid] = routes
      end
      def find(route)
        ret = []
        @cache.each do |id,routes|
          routes.each do |hash|
            entry = hash[:lapaz_route]
            ret << {route=>id} if entry[:externally_callable] && entry[:path] == route
          end
        end
        ret
      end
    end
    class Router
      include Blockenspiel::DSL
      attr_reader :path_handler, :name, :uuid
      def initialize(name)
        @name = name
        @uuid = lapazcfg.app.uuid
        @routes ||= {}
        @path_handler = PathHandler.new
        @queue = Queue.new
        @srv_queue = Queue.new
        @ctx = lapazcfg.app.ctx
        @endpt = lapazcfg.app.endpt

        @ext_services = ExtRoutesCache.new
        puts "... #{name} ... #{Time.now}"
      end

      dsl_methods false

      def enqueue(q_object, is_svc=false)
        #puts q_object.inspect
        if is_svc
          @srv_queue << q_object
        else
          @queue << q_object
        end
      end

      def update_external_services(services)
        @ext_services.add(services)
        puts "::::::::: external svcs: #{@ext_services.inspect}"
      end

      def services(external_only=false)
        svcs = @routes.values.map do |r|
          r.describe(external_only)
        end.flatten.compact
        {:app=>name, :app_id=>uuid, :routes=>svcs}
      end

      def publish(trans,q_object)
        route_name = q_object.route
        problem = true
        if @routes.has_key?(route_name)
          @routes[route_name].publish(trans, q_object)
          problem = false
        else
          what = q_object.ext_route
          found = @ext_services.find(what)
          unless found.empty?
            msg = DefCoder.decode(q_object.msg)
            msg[:headers][:external_routes] = found  #msg is normal hash not instance of Message
            q_able = Component::Queueable.new('svc_call',0,nil)
            q_able.msg = DefCoder.encode(msg)
            @routes['svc_call'].publish(trans, q_able)
            problem = false
          end
        end
        raise "Cannot find a route named: #{route_name}" if problem
      end

      def run()
        # for inproc have to bind before connecting in the component subscribe
        int = ZeroMqPub.new(@ctx, lapazcfg.app.endpt)
        int.setup_publish

        @routes.values.collect do |r|
          r.run
        end

        Thread.new do
          ext = ZeroMqPub.new(@ctx, lapazcfg.svc.endpt)
          ext.setup_publish
          loop do
            q_object = @srv_queue.pop
            ext.send(q_object.topic, q_object.msg)
          end
        end

        loop do
          publish int, @queue.pop
        end
      end

      def self.configure(app, &block)
        Blockenspiel.invoke(block, app) if block_given?
        app
      end

      def self.application(name,&block)
        app = new(name)
        Blockenspiel.invoke(block, app) if block_given?
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



