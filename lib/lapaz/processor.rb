module Lapaz
  module Processor
    class Base < Lapaz::Component
      def producer?; false; end
      def consumer?; false; end
    end

    class TmplCache < Hash
      def fetch path, to_=nil
        data, et = self[path]
        now = Time.now
        if !et or et < now
          data = yield
          self[path] = [data, now + (to_ || 1800)]
        end
        data
      end
      alias expire delete
      def purge
        now = Time.now
        delete_if do |_, (_, t)|
          t < now
        end
      end
    end
    class Renderer < Base
      def initialize(opts)
        super
        @cache = TmplCache.new
      end
    end
    class TemplateRenderer < Renderer
      def work(msg)
        path = msg.headers.delete(:view_template)
        path = File.join(lapazcfg.app_views.folder,path)
        template = @cache.fetch(path) { Tilt.new(path) }
        b = template.render(msg)
        msg.body[:mongrel_resp_body] = b
        msg
      end
    end

    class LayoutRenderer < Renderer
      def work(msg)
        path = msg.headers.delete(:view_layout) || 'default.erb'
        path = File.join(lapazcfg.app_views.folder,path)
        template = @cache.fetch(path) { Tilt.new(path) }
        b = template.render(){msg.body[:mongrel_resp_body]}
        msg.body[:mongrel_resp_body] = b
        msg
      end
    end

    class YamlProcessor < Base
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

    class Delayer < Base
      def initialize(opts)
        @delay_for = opts[:delay_for]
        super
      end
      def work(msg)
        Thread.new{sleep(@delay_for)}.join
        msg
      end
    end

    class MongoReader < Base
      def work(msg)
        #define
      end
    end

    class Tester < Base
      def work(msg)
            #simulate some work being done
            #Thread.new{sleep(rand/10.0)}.join
        msg
      end
    end
    class Purchases < Tester
      def work(msg)
        super
        pch = [{'id'=>'1234-DSF','contact_id'=>'886644','stock_id'=>'4521','notes'=>'rest of purchase object here'}]
        msg.add :body,{:purchases=>pch}
      end
    end
    class Contacts  < Tester
      def work(msg)
        super
        msg.add :body,{:contacts=>[{'id'=>'886644','name'=>'Bob Smith','age'=>32,'notes'=>'rest of contact object here'}]}
      end
    end
    class StockItems < Tester
      def work(msg)
        super
        msg.add :body,{:stock_items=>[{'id'=>'4521','name'=>'Widget X','price'=>45.21,'ccy'=>'EUR','notes'=>'rest of stock object here'}]}
      end
    end
  end
end
