
Thread.abort_on_exception = true

module Lapaz
  class Component

    attr_reader :addr, :sub_sock, :route_uuid, :sequence_id, :workunit, :loop_once

    #:route,
    def initialize(opts)
      @addr, @route_uuid, @sequence_id, @workunit = opts.values_at(:route_internal_addr, :route_uuid, :seq_id, :work)
      @loop_once = opts[:loop_once] || false
      @sub_topic = "#{@router_uuid}/#{@sequence_id}"
      @pub_topic = "#{@router_uuid}/#{@sequence_id.next}"
    end
    def to_hash
      {:route_uuid=>@route_uuid, :sequence_id=>@sequence_id, :addr=>@addr, :port=>@port}
    end
    def run(route)
      @route = route
      th = Thread.new do
        @sub_sock = @route.ctx.socket(ZMQ::SUB)
        @sub_sock.setsockopt(ZMQ::SUBSCRIBE,@sub_topic)
        @sub_sock.connect @addr
        #begin
          loop do
            msg = push(process(pull))
            if loop_once || msg.nil? || msg.headers[:stop_this_route] == route_uuid
              print "B#{sequence_id}|"
              break
            end
          end
        #rescue ZMQ::SocketError => e
        #  puts "!!!!----!!!!#{e.inspect}"
        #end
      end
    end

    def work(msg)
      # This method can be redefined in subclasses where the
      # code to execute is known at design time and
      # not supplied as a callable in the initial opts hash.
      # This and the callable should return the message for
      # the Lapaz::Message merge method or nil
      # header hash, body hash, errors array, warnings array.
      @workunit.respond_to?(:call) ? @workunit.call(msg) : msg
    end

    def push(msg)
      print "-#{sequence_id}|"
      @route.publish do |sock|
        sock.send_string(@pub_topic, ZMQ::SNDMORE) #TOPIC
        sock.send_string(BERT.encode(msg.to_hash)) #BODY
      end

      print "-#{sequence_id}"
      msg
    end

    def process(msg)
      print ":#{sequence_id}|"
      m = nil
      begin
        m = work(msg)
      rescue => e
        esrc = "#{route_uuid}/#{sequence_id}"
        m = msg.add_to :errors, {:error_source=>esrc, :error_message=>e.message}
      end
      m
    end

    def pull(msg=nil)

      topic = @sub_sock.recv_string
      body  = @sub_sock.more_parts? ? @sub_sock.recv_string : nil
      print "+#{sequence_id}|"
      h = body ? BERT.decode(body) : {}
      Lapaz::DefaultMessage.new(h)
    end

  end
end
