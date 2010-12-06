module Lapaz
  module Processor

    class Contacts  < Base
      def work(msg)
        super
        msg.add :body,{:contacts=>[{'id'=>'886644','name'=>'Bob Smith','age'=>32,'notes'=>'rest of contact object here'}]}
      end
    end

  end
end
