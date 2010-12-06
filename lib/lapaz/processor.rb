module Lapaz
  module Processor
    class Base < Lapaz::Component
      def producer?; false; end
      def consumer?; false; end
    end

    class TmplCache < Hash
      def fetch(path, to_=nil)
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
        delete_if do |_, (__, t)|
          t < now
        end
      end
    end

    class Unrecognized < Base
      def work(msg)
        msg.add :headers, {:path_params => {:action=>'path_not_found'}}
      end
    end

    class CallOutRunner < Base
      def work(msg)
        #TODO: better strategy for picking routes when multiple routes are offered by other apps
        routes = msg.headers[:external_routes]
        lap = routes.first
        route = lap.keys.first
        target = lap[route]
        msg.add :headers, {:svc_path=> "#{lapazcfg.svc.topic_base}/#{app.uuid}/#{target}/run/#{route}"}
      end
    end

    class CallOutReply < Base
      def work(msg)
        #
        msg
      end
    end

    class Services < Base
      def work(msg)
        source = msg.fetch(:headers,:path_params,:source)
        target = msg.fetch(:headers,:path_params,:target)
        action = msg.fetch(:headers,:path_params,:action)
        destination = (target =~ /(_all_|_any_)/) ? target : source
        case action
        when 'info'
          nil
        when 'update'
          # receive services available from other apps
          app.update_external_services(msg.body)
          msg.headers[:svc_path] = "#{lapazcfg.svc.topic_base}/#{app.uuid}/#{destination}/info"
          msg.add :body, {:info=>"Received ok from: #{app.name}"}
        when 'query'
          # send services available from this app
          app.update_external_services(msg.body)
          msg.headers[:svc_path] = "#{lapazcfg.svc.topic_base}/#{app.uuid}/#{destination}/update"
          msg.replace :body, app.services(true)
        when 'path_not_found'
          msg.add :errors, {:type=>'PathNotFound', :message=>"Path not found: #{msg.headers['PATH']}"}
        else
          # action unknown
          msg.add :errors, {:type=>'ActionUnknown', :message=>"Action: #{action} is not defined!"}
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
        format = msg.fetch(:headers,:path_params,:format)
        b = if format =~ /^js/
              {:mongrel_http_body=>msg.to_json_content, :mime=>'json'}
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

    class Delayer < Base
      def initialize(opts)
        @delay_for = opts[:delay_for]
        super
      end
      def work(msg)
        sleep(@delay_for)
        msg
      end
    end

    class NoopProcessor < Base
      def work(msg)
            #simulate some work being done
            #Thread.new{sleep(rand/10.0)}.join
        msg
      end
    end

  end
end
