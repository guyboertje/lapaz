module Lapaz
  module Processor

    class StockItems < Base
      def work(msg)
        super
        msg.add :body,{:stock_items=>[{'id'=>'4521','name'=>'Widget X','price'=>45.21,'ccy'=>'EUR','notes'=>'rest of stock object here'}]}
      end
    end

  end
end
