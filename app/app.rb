Thread.abort_on_exception = true

include Lapaz

app = Lapaz::Router.application('test_app') do

  route(:route_name=>"purchases") do
    from Processor::Purchases, {:seq_id=>0,:mux_id=>'2.1',:mongo_collection=>'purchases',:name=>'start',:ext=>true}
      to Consumer::Forwarder,{:seq_id=>0,:mux_id=>'2.2',:forward_to=>'prices/start',:reply_to=>'purchases/end'}
      to Consumer::ReplyToForwarder,{:seq_id=>1,:name=>'end'}
  end

  route(:route_name=>"prices") do
    from Processor::Prices, {:seq_id=>0,:name=>'start',:mongo_collection=>'prices',:ext=>true}
    to Consumer::ReplyToForwarder,{:seq_id=>1}
  end

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

  route(:route_name=>"svc_qry") do
    from Processor::Unrecognized,{:seq_id=>0,:name=>'err'}
      to Processor::Services,{:seq_id=>1,:name=>'start'}
      to Consumer::McastSender,{:seq_id=>2}
  end

  route(:route_name=>"svc_run") do
    from Processor::NoopProcessor,{:seq_id=>0,:name=>'start'}
      to Consumer::ExternalRunner,{:seq_id=>1,:reply_to=>'svc_run/send'}
      to Consumer::McastSender,{:seq_id=>2,:name=>'send'}
  end

  url_handlers do
    unrecognized do |path|
      if path.start_with? lapazcfg.svc.topic_base
        {:lapaz_route => 'svc_qry/err'}
      else
        {:lapaz_route => 'errors/mongrel', :view_template=>'url_unrecognized.erb', :view_layout=>nil}
      end
    end
    build :path_pattern => '/handlertest/purchases/:id.:format', :lapaz_route => 'purchases/start', :view_template=>'purchases.erb', :view_layout=>'default.erb'
    build :path_pattern => "#{lapazcfg.svc.topic_base}/:source/:target/run/:route/:seq", :lapaz_route => 'svc_run/start'
    build :path_pattern => "#{lapazcfg.svc.topic_base}/:source/:target/:action", :lapaz_route => 'svc_qry/start'
  end

end

p app.services.inspect

app.run()


=begin
  route(:route_name=>"purchases") do
    from Processor::Purchases, {:seq_id=>0,:name=>'start',:mongo_collection=>'purchases'}
      to Consumer::Forwarder,{:seq_id=>1,:mux_id=>'3.3',:forward_to=>'prices/start',:reply_to=>'purchases/render'}
      to Processor::Contacts,{:seq_id=>1,:mux_id=>'3.1'}
      to Processor::StockItems,{:seq_id=>1,:mux_id=>'3.2'}
      to Processor::TemplateRenderer,{:seq_id=>2,:name=>'render'}
      to Processor::LayoutRenderer,{:seq_id=>3}
      to Consumer::MongrelConsumer,{:seq_id=>4}
  end
  route(:route_name=>"reply_to_test") do
    from Producer::FileProducer, {:seq_id=>0,:name=>'start',:filename=>"/home/gb/dev/lapaz/lib/samples/test.data",:loop_once=>true}
      #to Processor::Prices, {:seq_id=>1}
      to Consumer::Forwarder,{:seq_id=>1,:forward_to=>'prices/start',:reply_to=>'reply_to_test/end'}
      to Consumer::Stdout,{:seq_id=>2,:name=>'end'}
  end
=end
