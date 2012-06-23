module Lapaz
  module ZeroFfi
    module Sub

      def subscribe(topic)
        unless @sock
          @sock = @ctx.socket(ZMQ::SUB)
          @sock.setsockopt(ZMQ::MCAST_LOOP,0)
          @sock.setsockopt(ZMQ::SUBSCRIBE,topic)
          @sock.connect @endpt
          puts "-S-#{@endpt} ... #{topic}" if lapazcfg.app.debug
        end
      end

      def receive
        topic = @sock.recv_string
        body  = @sock.more_parts? ? @sock.recv_string : nil
        puts "<s-#{topic}" if lapazcfg.app.debug
        [topic,body]
      end

      def close
        @sock.close
        @sock = nil
      end

    end

    module Pub

      def send(topic,body)
        puts "-p>#{topic}" if lapazcfg.app.debug
        @sock.send_string(topic, ZMQ::SNDMORE) #TOPIC
        @sock.send_string(body) #BODY
      end

      def setup_publish
        unless @sock
          @sock = @ctx.socket(ZMQ::PUB)
          @sock.setsockopt(ZMQ::MCAST_LOOP,0)
          @sock.bind @endpt
          if @endpt.start_with?("epgm")
            @sock.send_string("#{lapazcfg.svc.topic_base}/_all_/_all_/info", ZMQ::SNDMORE)
            @sock.send_string('{"kind":"info","headers":{},"body":{"info":"booted"},"errors":[],"warnings":[]}')
          end
          puts "-P-#{@endpt}" if lapazcfg.app.debug
        end
      end

      def close
        @sock.close
        @sock = nil
      end

    end
  end
  module ZeroJava

    module Sub

    end

    module Pub

    end

  end

  class ZeroMq

    attr_reader :ctx, :endpt, :sock

    def initialize(ctx,endpt)
      @ctx, @endpt = ctx, endpt
    end
    
  end

end
