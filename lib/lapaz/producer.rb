module Lapaz
  module Producer
    class Base < Lapaz::Component
      def producer?; true; end
      def consumer?; false; end
      # pull should return a hash with contents for sub topic and body
      # but for producers, first in line, there is no sub topic
      def pull(msg = Lapaz::DefaultMessage.new)
        msg.headers[:iter_id] = ::UUID.generate
        super msg
      end
    end

    class FileProducer < Base
      def initialize(opts={})
        @filename = opts.delete(:filename)
        super
      end

      def pull(msg = Lapaz::DefaultMessage.new(:kind=>'file_contents'))
        b = ""
        File.open(@filename) do |f|
          b = f.read
        end
        msg.body[:file_contents] = b
        super(msg)
      end
    end

    class YamlFileProducer < FileProducer
      def initialize(opts); super; @loop_once = true; end
      def work(msg)
        msg.add_to :headers,{:file_contents_type => 'yaml'}
      end
    end

    class TestProducer < Base
      def initialize(opts); super; @loop_once = true; end
      def work(msg)
        msg.add_to :body,{:request => {'action'=>'GET','path'=>'purchases/purchase','params'=>{'id'=>'1234-DSF'}}}
      end
    end

    NullProducer = Class.new(Base)
    ErroredMessageReceiver = Class.new(Base)

    class MongrelReceiver < Base
      def initialize(opts)
        super
        cfg = lapazcfg.mongrel(LpzEnv)
        unless cfg.conn
          cfg.conn = Mongrel2::Connection.new(cfg)
        end
        @connection = cfg.conn
      end

      def pull()
        h = {}
        #puts "waiting......"
        lapazcfg.mongrel(LpzEnv).conn.recv do |req|
          h = req.to_hash
        end
        msg = Lapaz::MongrelMessage.new(h)
        msg.headers[:iter_id] = ::UUID.generate
        #puts "mongrel message received: #{msg}"
        {:message=>msg, :topic=>nil}
      end
    end

  end
end
