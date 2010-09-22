module Lapaz
  module Producer
    class Base < Lapaz::Component
      def producer?; true; end
      def consumer?; false; end
    end

    class FileProducer < Base
      def initialize(opts={})
        @filename = opts.delete(:filename)
        super
      end

      def pull(msg = Lapaz::DefaultMessage.new(:kind=>'file_contents'))
        print "+#{sequence_id}|"
        b = ""
        File.open(@filename) do |f|
          b = f.read
        end
        msg.add_to :body,{:file_contents => b}
      end
    end
    class YamlFileProducer < FileProducer
      def work(msg)
        print ":#{sequence_id}|"
        msg.add_to :headers,{:file_contents_type => 'yaml'}
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
        Lapaz::Message::MongrelMessage.new(h)
      end
    end
=end
  end
end
