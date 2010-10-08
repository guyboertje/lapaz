module Lapaz
  module Consumer
    class Base < Lapaz::Component
      def producer?; false; end
      def consumer?; true; end
    end

    class Stdout < Base
      def work(msg)
        puts "RECV: #{msg.inspect}"
        Lapaz::DefaultMessage.new
      end
    end

    Forwarder = Class.new(Base)

    class MongrelForwarder < Base
      def push(msg)
        path = msg.headers['PATH']
        lapaz_route = @app.path_handler.handle(path)
        lap = lapaz_route.delete(:lapaz_route)
        msg.add_to :headers,lapaz_route
        r,s,m = lap.split('/',3)
        q_able = Queueable.new(r,s,m)
        super msg,q_able
      end
    end

    class MongrelConsumer < Base
      def initialize(opts)
        super
        cfg = lapazcfg.mongrel(LpzEnv)
        unless cfg.conn
          cfg.conn = Mongrel2::Connection.new(cfg)
        end
      end
      def push(msg)
        sender = msg.headers[:sender]
        cid = msg.headers[:conn_id]
        body = msg.body[:mongrel_resp_body]
        lapazcfg.mongrel(LpzEnv).conn.reply_http_resp(sender, cid, body)
        msg
      end

      def work(msg)
        #this will eventually be rendered
        return msg unless msg.body[:mongrel_resp_body].nil?

        msg.add_to :body, {:mongrel_resp_body=>"<pre>#{msg.inspect}</pre>"}
      end
    end
  end
end
