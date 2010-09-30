module Lapaz
  module Consumer
    class Base < Lapaz::Component
      def producer?; false; end
      def consumer?; true; end
      def push(msg)
        puts "CONSUMER: route ended"
        msg
      end
    end

    class Stdout < Base
      def work(msg)
        puts "RECV: #{msg.inspect}"
        Lapaz::DefaultMessage.new
      end
    end

    Forwarder = Class.new(Base)
  end
end
