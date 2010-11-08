module Lapaz
  module ZeroFfi
    module Sub
      def subscribe(topic)
        unless @sock
          @sock = @ctx.socket(ZMQ::SUB)
          @sock.setsockopt(ZMQ::SUBSCRIBE,topic)
          #puts "????? subscribe endpt: #{@endpt}, topic: #{topic}"
          @sock.connect @endpt
        end
      end
      def receive
        topic = @sock.recv_string
        body  = @sock.more_parts? ? @sock.recv_string : nil
        [topic,body]
      end
    end
    module Pub
      def send(topic,body)
        @sock.send_string(topic, ZMQ::SNDMORE) #TOPIC
        @sock.send_string(body) #BODY
      end
      def setup_publish
        unless @sock
          @sock = @ctx.socket(ZMQ::PUB)
          @sock.bind @endpt
        end
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
