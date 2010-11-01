module Lapaz
  module Mongo
    module Reader
      def read(search,opts={})
        # returns a cursor
        @collection.find(search,opts)
      end
      def read_one(search,opts={})
        @collection.find_one(search,opts)
      end
    end
    module Writer
      def write(obj,spec={},opts={})
        if spec.empty?
          _id = obj['_id'] || obj[:_id]
          id = obj['id'] || obj[:id]
          if _id
            spec['_id'] = _id
          elsif id
            spec['id'] = id
          else
            raise "No spec supplied and one could not be inferred"
          end
          opts[:upsert] = true
        end
        @collection.update(spec,obj,opts)
      end
    end
    module Accessor
      include Reader
      include Writer
    end
  end
end
