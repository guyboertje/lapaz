module Lapaz
  module Producer
    class Base < Lapaz::Component
      def producer?; true; end
      def consumer?; false; end
      # pull should return a hash with contents for sub topic and body
      # but for producers, first in line, there is no sub topic
      def pull(msg,trans)
        msg = Lapaz::DefaultMessage.new unless msg
        msg.add_iteration_id
        super(msg,trans)
      end
      def postamble(msg)
        msg.add_iteration_id
        {:message=>msg,:topic=>'NULL'}
      end
    end

    class Lurker < Base
      def initialize(opts)
        super
        ot = @sub_topic
        @ignore = ot.split('/',3).first
        @sub_topic = opts[:observe_topic] || ''
      end

      def pull(msg,trans)
        interested = false
        topic = body = nil
        until interested
          topic,body = trans.receive
          interested = !topic.start_with?(@ignore)
        end
        puts "----------------++++ RECV: #{topic}"
        msge = Lapaz::Message.new(body ? DefCoder.decode(body) : {}).merge!(msg)
        {:message=>msge,:topic=>topic}
      end
    end

    class Repeater < Base
      def initialize(opts)
        super
        @repeat = opts[:initial_x_secs] || 15
        @every = opts[:every_x_secs] || 120
      end

      def pull(msg,trans)
        topic = 'repeater/0'
        sleep(@repeat)
        msg = Lapaz::Message.new(:kind=>'repeater')
        {:message=>msg,:topic=>topic}
      end
      def work(msg)
        @repeat = @every
        msg
      end
    end

    class MongrelReceiver < Base
      def initialize(opts)
        super
        cfg = lapazcfg.mongrel
        unless cfg.conn
          cfg.conn = Mongrel2::Connection.new(cfg)
        end
        @connection = cfg.conn
      end

      def pull(msg,trans)
        h = {}
        while h.empty?
          req = lapazcfg.mongrel.conn.recv
          h = req.to_hash unless req.disconnect?
        end
        msg = Lapaz::MongrelMessage.new(h)
        postamble msg
      end
    end

    class McastReceiver < Lapaz::Component
      def initialize(opts)
        super
        @sub_topic = lapazcfg.svc.topic_base
        @endpt = lapazcfg.svc.endpt
      end

      def pull(msg,trans)
        got_one = false
        topic = body = nil
        until got_one
          topic, body = trans.receive
          from_us = topic.start_with?("#{lapazcfg.svc.topic_base}/#{app.uuid}")
          for_us = !!(topic =~ lapazcfg.svc.for_us_re)
          got_one = for_us && !from_us
        end
        msge = Lapaz::McastMessage.new(ExtCoder.decode(body))
        msge.headers['PATH'] = topic
        {:message=>msge,:topic=>topic}
      end
    end
  end
end
