module Lapaz
  module Producer
    class Base < Lapaz::Component
      def producer?; true; end
      def consumer?; false; end
      # pull should return a hash with contents for sub topic and body
      # but for producers, first in line, there is no sub topic
      def pull(msg = Lapaz::DefaultMessage.new)
        msg.headers[:iter_id] = ::UUID.generate
        {:message=>msg, :topic=>nil}
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

=begin
    class MongrelProducer < Base

      attr_accessor :conn

      def initialize(opts={})
        @conn = Mongrel2::Connection.new(*opts.values_at(:sender_id,:req_addr,:rep_addr))
        super
      end

      def pull()
        h = {}
        @conn.recv do |req|
          h = req.to_hash
        end
        msg = Lapaz::Message::MongrelMessage.new(h)
        msg.headers[:iter_id] = ::UUID.generate
        {:message=>msg, :topic=>nil}
      end
    end
=end
  end
end
