
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
    def setup_routes
      opts = {:route_internal_addr=>"tcp://127.0.0.1:14900"}
      opts[:route_uuid] = ::UUID.generate
      opts[:loop_once] = true
      print '|'
      add_route init(opts).
                from(Lapaz::Producer::YamlFileProducer.new(opts.merge({:seq_id=>0,:filename=>"/home/gb/dev/lapaz/lib/test.yml"}))).
                to(Lapaz::Processor::YamlProcessor.new(opts.merge({:seq_id=>1}))).
                to(Lapaz::Consumer::Stdout.new(opts.merge({:seq_id=>2})))
    end
  end
  TestRouter.start()
end
