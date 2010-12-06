module Lapaz
  module Processor

    class Prices < Base
      include Lapaz::Mongo::Reader

      def initialize(opts)
        @collection = lapazcfg.mongo.db.collection(opts.delete(:mongo_collection))
        super
      end

      def work(msg)
        super
        find = {'ccy_pair'=>'EURGBP'}
        prices = []
        read(find).each do |doc|
          prices << doc.to_hash
        end
        msg.add :body,{:prices=>prices}
      end
    end

  end
end
