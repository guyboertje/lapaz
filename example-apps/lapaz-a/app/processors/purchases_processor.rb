module Lapaz
  module Processor

    class Purchases < Base
      include Lapaz::Mongo::Reader

      def initialize(opts)
        @collection = lapazcfg.mongo.db.collection(opts.delete(:mongo_collection))
        super
      end

      def work(msg)
        super
        id = msg.fetch(:headers,:path_params,:id)
        #is something?
        find = {'id'=>id}
        purchases = []
        read(find).each do |doc|
          purchases << doc.to_hash
        end
        msg.add :body,{:purchases=>purchases}
      end
    end

  end
end
