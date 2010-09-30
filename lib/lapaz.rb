
requires = %W;thread rubygems ffi-rzmq bert yaml uuid;
requires += %W;lapaz/message lapaz/component lapaz/producer lapaz/consumer lapaz/processor lapaz/router;
requires.each do |lib|
  require lib
end
#require 'lapaz/eip' m2r/connection
#require 'lapaz/filter'

if __FILE__ == $0

  Thread.abort_on_exception = true

  #[:INT, :TERM].each { |sig| trap(sig) {ZCTX.terminate} }
  class TestRouter < Lapaz::Router
    include Lapaz::Producer
    include Lapaz::Processor
    include Lapaz::Consumer
    def setup_routes

      o3 = {:route_internal_addr=>"tcp://127.0.0.1:14904",:route_name=>"forward_test",:seq_id=>0}
      add_route from(TestProducer,o3).
                to(Delayer,{:seq_id=>1, :delay_for=>3}).
                to(Forwarder,{:seq_id=>2, :forward_to=>'parallel_test', :forward_at=>'purchase'})
#
      o2 = {:route_internal_addr=>"tcp://127.0.0.1:14902",:route_name=>"yaml_test",:seq_id=>0}
      o2[:filename] = "/home/gb/dev/lapaz/lib/test.yml"
      add_route from(YamlFileProducer,o2).
                to(YamlProcessor,{:seq_id=>1}).
                to(Stdout,{:seq_id=>2})

      o1 = {:route_internal_addr=>"tcp://127.0.0.1:14900",:route_name=>"parallel_test",:seq_id=>0}
      add_route from(TestProducer,o1).
                to(Purchases,{:seq_id=>1,:name=>'purchase'}).
                to(Contacts,{:seq_id=>2,:mux_id=>'2.1'}).
                to(StockItems,{:seq_id=>2,:mux_id=>'2.2'}).
                to(Stdout,{:seq_id=>3})


    end
  end
  TestRouter.start()
end
