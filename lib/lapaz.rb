
requires = %W;rubygems ffi-rzmq bert yaml uuid;
requires += %W;lapaz/message lapaz/component lapaz/producer lapaz/consumer lapaz/processor lapaz/router;
requires.each do |lib|
  require lib
end
#require 'lapaz/eip' m2r/connection
#require 'lapaz/filter'

if __FILE__ == $0

  Thread.abort_on_exception = true

  ZADDR = "tcp://127.0.0.1--14900"
  OPTS = {:route_internal_addr=>ZADDR}
  #[:INT, :TERM].each { |sig| trap(sig) {ZCTX.terminate} }
  class TestRouter < Lapaz::Router
    def setup_routes
      opts = OPTS.dup
      opts[:route_uuid] = ::UUID.generate
      opts[:loop_once] = true
      print '|'
      add_route from(Lapaz::Producer::YamlFileProducer.new(opts.merge({:seq_id=>0,:filename=>"/home/gb/dev/lapaz/lib/test.yml"}))).
                  to(Lapaz::Processor::YamlProcessor.new(opts.merge({:seq_id=>1}))).
                  to(Lapaz::Consumer::Stdout.new(opts.merge({:seq_id=>2})))
    end
  end
  TestRouter.start()
end
