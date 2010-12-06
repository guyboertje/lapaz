module Lapaz
  module BertCoder
    def encode(obj)
      BERT.encode(obj)
    end
    def decode(obj)
      BERT.decode(obj)
    end
  end

  module JsonCoder
    def encode(obj)
      return obj if obj.kind_of?(String)
      obj.to_json
    end
    def decode(obj)
      return obj unless obj.kind_of?(String) && obj.start_with?("{")
      JSON.parse(obj, :symbolize_names=>true)
    end
  end

  DefCoder = Class.new()
  ExtCoder = Class.new()
end
