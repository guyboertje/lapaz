
# mixin Bert for message transcoding
Lapaz::DefCoder.extend(Lapaz::BertCoder)
Lapaz::ExtCoder.extend(Lapaz::JsonCoder)

Lapaz::ZeroMqSub = Class.new(Lapaz::ZeroMq) { include Lapaz::ZeroFfi::Sub }
Lapaz::ZeroMqPub = Class.new(Lapaz::ZeroMq) { include Lapaz::ZeroFfi::Pub }

#require 'java'
#require 'zmq.jar'
#Lapaz::ZeroMqSub = Class.new(Lapaz::ZeroMq) { include Lapaz::ZeroJava::Sub}
#Lapaz::ZeroMqPub = Class.new(Lapaz::ZeroMq) { include Lapaz::ZeroJava::Pub}

# when defining multiple apps for this runtime use the appname as the slice key
#  e.g. app 1 is called 'apollo' and app 2 'hermes'
#  to have separate slices of config add the app name into the set and get
#  lapazcfg('apollo').mongrel = {} and
#  lapazcfg('hermes').mongrel = {}

_ctx = ZMQ::Context.new(1)
_app_id = UUID.generate
_svc_topic_base = "lapaz/svc"
lapazcfg.mongrel = {:sender_id=>::UUID.generate,:scheme=>"tcp",:host=>"127.0.0.1",:req_port=>"9997",:rep_port=>"9996", :ctx=>_ctx, :conn=>nil}

#epgm://eth0;239.192.1.1:1100
lapazcfg.svc = {:scheme=>"epgm",:host=>"239.192.1.1",:port=>"100", :endpt=>"", :ctx=>_ctx, :topic_base=>_svc_topic_base, :for_us_re=>nil}
lapazcfg.svc do |cfg|
  cfg.endpt = "#{cfg.scheme}://lo;#{cfg.host}:#{PortPfx}#{cfg.port}"
  cfg.for_us_re = /^#{_svc_topic_base}\/.+\/(#{_app_id}|_all_|_any_)/
end

#lapazcfg.app = {:scheme=>"tcp",:host=>"127.0.0.1",:port=>"4066", :endpt=>"", :ctx=>_ctx}
lapazcfg.app = {:uuid=>"",:scheme=>"inproc",:key=>"lapaz", :endpt=>"", :ctx=>_ctx}
lapazcfg.app do |cfg|
  cfg.uuid = _app_id
  case cfg.scheme
  when "tcp"
    cfg.endpt = "#{cfg.scheme}://#{cfg.host}:#{PortPfx}#{cfg.port}"
  when "inproc"
    cfg.endpt = "#{cfg.scheme}://#{cfg.key}"
  end
end

vfolder = File.join(AppDir,"views")

lapazcfg.app_views = {:folder=>vfolder,:default_engine=>"erubis"}

db = nil
lapazcfg.mongo = {:host=>"127.0.0.1",:port=>"7037",:db_name=>"lapaz_md",:con_cfg=>{:pool_size => 5, :timeout => 3.0},:con=>nil, :db=>nil}
lapazcfg.mongo do |cfg|
  cfg.con = Mongo::Connection.new(cfg.host, (PortPfx + cfg.port).to_i, cfg.con_cfg)
  db = cfg.db = cfg.con.db(cfg.db_name)
end





populate = false
# populate the db
if populate
  ['prices','purchases','contacts','inventories'].each do |coll|
    db.drop_collection(coll)
  end

  prices = [{'ccy_pair'=>'EURGBP','bid'=>'0.87330','offer'=>'0.87427'},{'ccy_pair'=>'GBPEUR','bid'=>'1.14381','offer'=>'1.14508'}]
  res = db.collection('prices').insert(prices)
  puts "Insert results: #{res.inspect}"

  purchase= {'id'=>'1234-DSF',
              'contacts'=>{'id'=>'886644','name'=>'Bob Smith'},
              'items'=>[{'id'=>'4521','name'=>'Widget X','price'=>45.21,'ccy'=>'EUR'}],
              'notes'=>'rest of purchase object here'
  }
  res = db.collection('purchases').insert(purchase)
  puts "Insert results: #{res.inspect}"

  contact = {'id'=>'886644','name'=>'Bob Smith','age'=>32,'notes'=>'rest of contact object here'}
  res = db.collection('contacts').insert(contact)
  puts "Insert results: #{res.inspect}"

  stock = {'id'=>'4521','name'=>'Widget X','price'=>45.21,'ccy'=>'EUR','notes'=>'rest of stock object here'}
  res = db.collection('inventories').insert(stock)
  puts "Insert results: #{res.inspect}"

end
#[:INT, :TERM].each { |sig| trap(sig){ lapazcfg.app.ctx.terminate } }













