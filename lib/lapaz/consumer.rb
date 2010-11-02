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

    class Forwarder < Base
      def push(msg)
        super(Message.new_keep_headers(msg))
      end
    end

    class ReplyToForwarder < Base
      def push(msg)
        q_able = nil
        if msg.headers.has_key?(:reply_to)
          reply_to = msg.headers.delete(:reply_to)
          r,s,m = reply_to.split('/',3)
          q_able = Queueable.new(r,s,m)
        end
        super(msg,q_able)
      end
    end

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
        cfg = lapazcfg.mongrel
        unless cfg.conn
          cfg.conn = Mongrel2::Connection.new(cfg)
        end
      end
      def push(msg)
        sender,cid = msg.headers.values_at(:sender,:conn_id)
        httpbody,httpheaders  = msg.body.values_at(:mongrel_http_body,:mongrel_http_hdrs)
        lapazcfg.mongrel.conn.reply_http_resp(sender, cid, httpbody, 200, httpheaders)
        msg
      end

      def work(msg)
        mime = (msg.body[:mime] == 'json') ? "application/json" : "text/html"
        msg.body[:mongrel_http_hdrs] = {'Content-type'=>"#{mime}; charset=utf-8"}

        return msg unless msg.body[:mongrel_http_body].nil?

        msg.add_to :body, {:mongrel_http_body=>"<pre>#{msg.inspect}</pre>"}
      end
    end
  end
end



