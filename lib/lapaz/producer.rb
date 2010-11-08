module Lapaz
  module Producer
    class Base < Lapaz::Component
      def producer?; true; end
      def consumer?; false; end
      # pull should return a hash with contents for sub topic and body
      # but for producers, first in line, there is no sub topic
      def pull(msg,trans)
        msg = Lapaz::DefaultMessage.new unless msg
        msg.headers[:iter_id] = ::UUID.generate
        super(msg,trans)
      end
      def postamble(msg)
        msg.headers[:iter_id] = ::UUID.generate
        {:message=>msg,:topic=>'NULL'}
      end
    end

    class FileProducer < Base
      def initialize(opts={})
        @filename = opts.delete(:filename)
        super
      end

      def pull(msg,skt)
        msg = Lapaz::DefaultMessage.new(:kind=>'file_contents') unless msg
        b = ""
        File.open(@filename) do |f|
          b = f.read
        end
        msg.body[:file_contents] = b
        postamble msg
      end
    end

    class YamlFileProducer < FileProducer
      def initialize(opts); super; @loop_once = true; end
      def work(msg)
        msg.add_to :headers,{:file_contents_type => 'yaml'}
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
        lapazcfg.mongrel.conn.recv do |req|
          h = req.to_hash
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
          topic,body = trans.receive
          from_us = topic.start_with?("#{lapazcfg.svc.topic_base}/#{app.uuid}")
          for_us = !!(topic =~ lapazcfg.svc.for_us_re)
          got_one = for_us && !from_us
        end
        msge = Lapaz::DefaultMessage.new(body ? ExtCoder.decode(body) : {}).merge!(msg)
        msge.headers['PATH'] = topic
        #puts "<<-#{topic}"
        {:message=>msge,:topic=>topic}
      end
    end
  end
end
