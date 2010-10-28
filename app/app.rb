Thread.abort_on_exception = true

include Lapaz

app = Lapaz::Router.application('test_app') do

  route(:route_name=>"purchases") do
    from Processor::Purchases, {:seq_id=>0,:name=>'start'}
      to Consumer::Forwarder,{:seq_id=>1,:forward_to=>'prices/start',:reply_to=>'purchases/render/3.3'}
      to Processor::Contacts,{:seq_id=>1,:mux_id=>'3.1'}
      to Processor::StockItems,{:seq_id=>1,:mux_id=>'3.2'}
      to Processor::TemplateRenderer,{:seq_id=>2,:name=>'render'}
      to Processor::LayoutRenderer,{:seq_id=>3}
      to Consumer::MongrelConsumer,{:seq_id=>4}
  end

  route(:route_name=>"prices") do
    from Processor::Prices, {:seq_id=>0,:name=>'start'}
    to Consumer::ReplyToForwarder,{:seq_id=>1}
  end

  route(:route_name=>"mongrel_test") do
    from Producer::MongrelReceiver,{:seq_id=>0}
    to   Consumer::MongrelForwarder,{:seq_id=>1}
  end

  route(:route_name=>"errors") do
    from Processor::TemplateRenderer,{:seq_id=>0,:name=>'mongrel'}
      to Consumer::MongrelConsumer,{:seq_id=>1}
  end


  url_handlers do
    unrecognized { {:lapaz_route => 'errors/mongrel', :view_template=>'url_unrecognized.erb', :view_layout=>nil} }
    build :url_pattern =>'/handlertest/purchases/:id.:format', :lapaz_route => 'purchases/start', :view_template=>'purchases.erb', :view_layout=>'default.erb'
  end

end

p app.services.inspect

app.run()


=begin

  route(:route_name=>"reply_to_test") do
    from Producer::FileProducer, {:seq_id=>0,:name=>'start',:filename=>"/home/gb/dev/lapaz/lib/samples/test.data",:loop_once=>true}
      #to Processor::Prices, {:seq_id=>1}
      to Consumer::Forwarder,{:seq_id=>1,:forward_to=>'prices/start',:reply_to=>'reply_to_test/end'}
      to Consumer::Stdout,{:seq_id=>2,:name=>'end'}
  end

    o3 = {:route_name=>"forward_test",:seq_id=>0}
    add_route from(TestProducer,o3).
              to(Delayer,{:seq_id=>1, :delay_for=>3}).
              to(Forwarder,{:seq_id=>2, :forward_to=>'parallel_test/purchase'})

    o2 = {:route_name=>"yaml_test",:seq_id=>0}
    o2[:filename] = "/home/gb/dev/lapaz/lib/samples/test.yml"
    add_route from(YamlFileProducer,o2).
              to(YamlProcessor,{:seq_id=>1}).
              to(Stdout,{:seq_id=>2})
=end
