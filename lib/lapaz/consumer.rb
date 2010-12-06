module Lapaz
  module Consumer
    class Base < Lapaz::Component
      def producer?; false; end
      def consumer?; true; end
    end

    class Stdout < Base
      def work(msg)
        puts "-------------------- RECV: #{msg.inspect}"
        nil
      end
    end

    class Looper < Base
      def initialize(opts)
        super
        @loop_to = opts[:loop_to]
      end
      def push(msg)
        q_msg = q_able || Queueable.new(@pub_to,@loop_to,@mux_id)
        q_msg.msg = DefCoder.encode(msg.to_hash)
        @app.enqueue(q_msg)
        msg
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
        #puts "headers: " + msg.headers.inspect
        reply_to = msg.headers[:reply_to].pop
        if reply_to
          r,s,m = reply_to.split('/',3)
          q_able = Queueable.new(r,s,m)
        end
        super(msg,q_able)
      end
    end

    class PathForwarder < Base
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

    class McastSender < Base
      def push(msg,q_able=nil)
        r,s,m = msg.headers[:svc_path], -1, nil
        if r
          q_msg = Queueable.new(r,s,m)
          q_msg.msg = ExtCoder.encode(msg.to_hash)
          @app.enqueue(q_msg,true)
        end
        msg
      end
    end

    class McastQuery < McastSender
      def work(msg)
        msg.headers[:svc_path] = "#{lapazcfg.svc.topic_base}/#{app.uuid}/_all_/query"
        msg.replace :body, app.services(true)
      end
    end

    class CallInRunner < Base
      def work(msg)
        source = msg.fetch(:headers,:path_params,:source)
        route = msg.fetch(:headers,:path_params,:route)
        seq = msg.fetch(:headers,:path_params,:seq)
        msg.add :headers, {:route_to_run=> "#{route}/#{seq}", :svc_path => "#{lapazcfg.svc.topic_base}/#{app.uuid}/#{source}/reply"}
      end
      def push(msg,q_able=nil)
        if @reply_to
          msg.add_reply_to @reply_to
        end
        lap = msg.headers.delete(:route_to_run)
        r,s,m = lap.split('/',3)
        if r
          q_msg = Queueable.new(r,s,m)
          q_msg.msg = DefCoder.encode(msg.to_hash)
          @app.enqueue(q_msg,false)
        end
        msg
      end
    end

    class MongrelResponder < Base
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
        mime = (msg.body['mime'] == 'json') ? "application/json" : "text/html"
        msg.body[:mongrel_http_hdrs] = {'Content-type'=>"#{mime}; charset=utf-8"}

        return msg unless msg.body[:mongrel_http_body].nil?

        msg.add_to :body, {:mongrel_http_body=>"<pre>#{msg.inspect}</pre>"}
      end
    end
  end
end



