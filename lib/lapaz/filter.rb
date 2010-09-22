module Lapaz
  module Filter
    class Base < Lapaz::Component

    end

    class DefaultFilter < Lapaz::Component
      def initialize(&block)
        @predicate = block
      end

      def process(message)
        return nil unless @predicate.call(message)
        return message
      end
    end
  end
end
