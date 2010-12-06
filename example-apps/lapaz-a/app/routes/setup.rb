def add_app_routes(_)

  Router.configure _ do

    route(:route_name=>"purchases") do
      from Processor::Purchases, {:seq_id=>0,:mux_id=>'2.1',:mongo_collection=>'purchases',:name=>'start',:ext=>true}
        to Consumer::Forwarder,{:seq_id=>0,:mux_id=>'2.2',:forward_to=>'prices/start',:reply_to=>'purchases/end'}
        #to Processor::Delayer,{:seq_id=>0,:mux_id=>'2.3',:delay_for=>3} #kind of timeout
        to Consumer::ReplyToForwarder,{:seq_id=>1,:name=>'end'}
    end
=begin

    route(:route_name=>"prices") do
      from Processor::Prices, {:seq_id=>0,:name=>'start',:mongo_collection=>'prices',:ext=>true}
      to Consumer::ReplyToForwarder,{:seq_id=>1}
    end

    route(:route_name=>"logger") do
      from Producer::Lurker,{:seq_id=>0, :observe_topic=>lapazcfg.app.topic_base }
        to Consumer::Stdout,{:seq_id=>1}
    end
=end


  end
end
