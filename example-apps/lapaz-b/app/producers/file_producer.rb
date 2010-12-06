module Lapaz
  module Producer

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

  end
end
