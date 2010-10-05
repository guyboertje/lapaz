Thread.abort_on_exception = true

class App < Lapaz::Router
  include Lapaz::Producer
  include Lapaz::Processor
  include Lapaz::Consumer

  def setup_routes
    puts "---"
    add_route from(NullProducer,{:route_name=>"purchases",:seq_id=>0}).
              to(Purchases,{:seq_id=>1,:name=>'start'}).
              to(Contacts,{:seq_id=>2,:mux_id=>'2.1'}).
              to(StockItems,{:seq_id=>2,:mux_id=>'2.2'}).
              to(MongrelConsumer,{:seq_id=>3})
    puts "---"
    add_route from(MongrelReceiver,{:route_name=>"mongrel_test",:seq_id=>0}).
              to(MongrelForwarder,{:seq_id=>1})
    puts "---"
#    add_route from(ErroredMessageReceiver,{:route_name=>"errors",:seq_id=>0}).
#              to(MongrelConsumer,{:seq_id=>1,:name=>'mongrel'})
#    puts "---"
    define_handlers do |handler|
      handler.build :url_pattern =>'/handlertest/purchases/:id', :lapaz_route => 'purchases/start'
    end

  end
end






=begin
    o3 = {:route_name=>"forward_test",:seq_id=>0}
    add_route from(TestProducer,o3).
              to(Delayer,{:seq_id=>1, :delay_for=>3}).
              to(Forwarder,{:seq_id=>2, :forward_to=>'parallel_test', :forward_at=>'purchase'})

    o2 = {:route_name=>"yaml_test",:seq_id=>0}
    o2[:filename] = "/home/gb/dev/lapaz/lib/test.yml"
    add_route from(YamlFileProducer,o2).
              to(YamlProcessor,{:seq_id=>1}).
              to(Stdout,{:seq_id=>2})
=end
