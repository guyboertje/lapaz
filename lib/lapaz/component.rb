
Thread.abort_on_exception = true

module Lapaz
  class Component

    attr_reader :addr, :port, :route_uuid, :sequence_id, :workunit, :pub_addr, :sub_addr, :loop_once

    def initialize(opts)
      base, @route_uuid, @sequence_id, @workunit = opts.values_at(:route_internal_addr, :route_uuid, :seq_id, :work)
      @loop_once = opts[:loop_once] || false
      @addr, p = base.split('--')
      @port = p.to_i + @sequence_id
    end
    def to_hash
      {:route_uuid=>@route_uuid, :sequence_id=>@sequence_id, :addr=>@addr, :port=>@port}
    end
    def run()
      th = Thread.new do
        ctx = ZMQ::Context.new(1)
        #unless producer?
          @sub_addr = @addr + ":" + @port.to_s
          @sub_sock = ctx.socket(ZMQ::PULL)
          @sub_sock.connect @sub_addr
        #end
        #unless consumer?
          @pub_addr = @addr + ":" + @port.next.to_s
          @pub_sock = ctx.socket(ZMQ::PUSH)
          @pub_sock.bind @pub_addr
        #end
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
      th.join
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
      #pub_sock.send_string("#{route_uuid}/#{sequence_id.next}", ZMQ::SNDMORE) #TOPIC
      @pub_sock.send_string(BERT.encode(msg.to_hash))                          #BODY
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
      body = @sub_sock.recv_string
      #topic = sub_sock.recv_string
      #body  = sub_sock.more_parts? ? sub_sock.recv_string : nil
      print "+#{sequence_id}|"
      h = body ? BERT.decode(body) : {}
      Lapaz::DefaultMessage.new(h)
    end

  end
end
