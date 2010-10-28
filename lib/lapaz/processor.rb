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
        params = msg.headers[:path_params]
        b = if params && params[:format] =~ /^js/
              {:mongrel_http_body=>msg.to_json, :mime=>'json'}
            else
              path = msg.headers.delete(:view_template)
              path = File.join(lapazcfg.app_views.folder,path)
              template = @cache.fetch(path) { Tilt.new(path) }
              {:mongrel_http_body=>template.render(msg), :mime=>'html'}
            end
        msg.add_to :body, b
      end
    end

    class LayoutRenderer < Renderer
      def work(msg)
        return msg unless msg.body[:mime] == 'html'
        path = msg.headers.delete(:view_layout) || 'default.erb'
        path = File.join(lapazcfg.app_views.folder,path)
        template = @cache.fetch(path) { Tilt.new(path) }
        msg.body[:mongrel_http_body] = template.render(){msg.body[:mongrel_http_body]}
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

    class Tester < Base
      def work(msg)
            #simulate some work being done
            #Thread.new{sleep(rand/10.0)}.join
        msg
      end
    end

    class Prices < Base
      include Lapaz::Mongo::Accessor
      def initialize(opts)
        @collection = lapazcfg.mongo.db.collection(opts[:mongo_collection])
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

    class Purchases < Tester
      def work(msg)
        super
        msg.add :body,{:purchases=>[{'id'=>'1234-DSF','contact_id'=>'886644','stock_id'=>'4521','notes'=>'rest of purchase object here'}]}
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
