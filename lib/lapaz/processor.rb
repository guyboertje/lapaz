module Lapaz
  module Processor
    module Base
      def producer?; false; end
      def consumer?; false; end
    end

    class TemplateRenderer < Lapaz::Component
      include Base

      def work(msg)

        path = msg.headers.delete(:view_template)
        path = File.join(lapazcfg.app_views(LpzEnv).folder,path)
        #cache this
        template = Tilt.new(path)
        puts "#{@route_name} #{@seq_id} doing some work.--."
        b = template.render(msg)
        msg.body[:mongrel_resp_body] = b
        msg
      rescue => e
        esrc = @sub_topic
        msg.add_to :errors, {:error_source=>esrc, :error_message=>e.message}
      end
    end

    class LayoutRenderer < Lapaz::Component
      include Base

      def work(msg)

        path = msg.headers.delete(:view_layout) || 'default.erb'
        puts "#{@route_name} #{@seq_id} doing some work.--."
        path = File.join(lapazcfg.app_views(LpzEnv).folder,path)

        #cache this
        template = Tilt.new(path)
        puts path.inspect
        b = template.render(){msg.body[:mongrel_resp_body]}
        msg.body[:mongrel_resp_body] = b
        msg
      rescue => e
        esrc = @sub_topic
        msg.add_to :errors, {:error_source=>esrc, :error_message=>e.message}
      end
    end

    class YamlProcessor < Lapaz::Component
      include Base
      def work(msg)
        key,obj = :warnings,"YamlProcessor: no work to do"
        if msg.headers[:file_contents_type] == 'yaml'
          xfrm = YAML.parse(msg.body[:file_contents]).transform
          key,obj = :body,{xfrm.type_id.to_sym => [xfrm.value]}
          msg.headers.delete(:file_contents_type)
          msg.body.delete(:file_contents)
        end
        msg.add_to key,obj
      end
    end
    class Delayer < Lapaz::Component
      def initialize(opts)
        @delay_for = opts[:delay_for]
        super
      end
      def work(msg)
        Thread.new{sleep(@delay_for)}.join
        msg
      end
    end
    class MongoReader < Lapaz::Component
      include Base
      def work(msg)
        dfadf
      end
    end
    class Tester < Lapaz::Component
      include Base
      def work(msg)
        #simulate some work being done
        #Thread.new{sleep(rand/10.0)}.join
        msg
      end
    end
    class Purchases < Tester
      include Base
      def work(msg)
        super
        pch = [{'id'=>'1234-DSF','contact_id'=>'886644','stock_id'=>'4521','notes'=>'rest of purchase object here'}]
        msg.add :body,{:purchases=>pch}
      end
    end
    class Contacts  < Tester
      include Base
      def work(msg)
        super
        msg.add :body,{:contacts=>[{'id'=>'886644','name'=>'Bob Smith','age'=>32,'notes'=>'rest of contact object here'}]}
      end
    end
    class StockItems < Tester
      include Base
      def work(msg)
        super
        msg.add :body,{:stock_items=>[{'id'=>'4521','name'=>'Widget X','price'=>45.21,'ccy'=>'EUR','notes'=>'rest of stock object here'}]}
      end
    end
  end
end
=begin
:purchases=>[{"id"=>"1234-DSF", "contact_id"=>"886644", "stock_id"=>"4521", "notes"=>"rest of purchase object here"}]

:stock_items=>[{"id"=>"4521", "name"=>"Widget X", "price"=>45.21, "ccy"=>"EUR", "notes"=>"rest of stock object here"}]

:contacts=>[{"id"=>"886644", "name"=>"Bob Smith", "age"=>32, "notes"=>"rest of contact object here"}]
=end
