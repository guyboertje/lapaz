def add_sys_config(_)

  Router.configure _ do

    route(:route_name=>"mongrel_handler") do
      from Producer::MongrelReceiver,{:seq_id=>0}
        to Consumer::PathForwarder,{:seq_id=>1,:reply_to=>'mongrel_handler/render'}
        to Processor::TemplateRenderer,{:seq_id=>2,:name=>'render'}
        to Processor::LayoutRenderer,{:seq_id=>3}
        to Consumer::MongrelResponder,{:seq_id=>4}
    end

    route(:route_name=>"errors") do
      from Processor::TemplateRenderer,{:seq_id=>0,:name=>'mongrel'}
        to Consumer::MongrelResponder,{:seq_id=>1}
    end

    route(:route_name=>"services") do
      from Producer::McastReceiver,{:seq_id=>0}
        to Consumer::PathForwarder,{:seq_id=>1}
    end

    route(:route_name=>"svc_advertise") do
      from Producer::Repeater,{:seq_id=>0,:every_x_secs=>180}
        to Consumer::McastQuery,{:seq_id=>1}
    end

    route(:route_name=>"svc_reply") do
      from Processor::CallOutReply,{:seq_id=>0,:name=>'start'}
        to Consumer::ReplyToForwarder,{:seq_id=>1}
    end

    route(:route_name=>"svc_qry") do
      from Processor::Unrecognized,{:seq_id=>0,:name=>'err'}
        to Processor::Services,{:seq_id=>1,:name=>'start'}
        to Consumer::McastSender,{:seq_id=>2}
    end

    route(:route_name=>"svc_run") do
      from Processor::NoopProcessor,{:seq_id=>0,:name=>'start'}
        to Consumer::CallInRunner,{:seq_id=>1,:reply_to=>'svc_run/send'}
        to Consumer::McastSender,{:seq_id=>2,:name=>'send'}
    end

    route(:route_name=>"svc_call") do
      from Processor::CallOutRunner,{:seq_id=>0,:name=>'start'}
        to Consumer::McastSender,{:seq_id=>1,:name=>'send'}
    end

    url_handlers do
      build :path_pattern => '/handlertest/purchases/:id.:format', :lapaz_route => 'purchases/start', :view_template=>'purchases.erb', :view_layout=>'default.erb'
      unrecognized do |path|
        if path.start_with? lapazcfg.svc.topic_base
          {:lapaz_route => 'svc_qry/err'}
        else
          {:lapaz_route => 'errors/mongrel', :view_template=>'url_unrecognized.erb', :view_layout=>nil}
        end
      end
      build :path_pattern => "#{lapazcfg.svc.topic_base}/:source/:target/run/:route/:seq", :lapaz_route => 'svc_run/start'
      build :path_pattern => "#{lapazcfg.svc.topic_base}/:source/:target/reply", :lapaz_route => 'svc_reply/start'
      build :path_pattern => "#{lapazcfg.svc.topic_base}/:source/:target/:action", :lapaz_route => 'svc_qry/start'
    end

  end
end
