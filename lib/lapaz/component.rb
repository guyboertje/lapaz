
Thread.abort_on_exception = true

module Lapaz
  class Component
    class Accumulator
      attr_reader :count, :max
      def initialize(msg,max)
        @count = 1
        @accumulator = msg
        @max = max
      end
      def push(msg)
        @accumulator.merge!(msg)
        @count += 1
      end
      def max?
        !(count < max)
      end
      def message
        @accumulator
      end
    end
    DEMUX_RE = /.+\/[0-9]+\/([0-9]+)\.([0-9]+)/
    attr_reader :addr, :sub_sock, :route_name, :seq_id, :mux_id, :workunit, :loop_once

    #:route,
    def initialize(opts)
      @addr, @seq_id, @workunit = opts.values_at(:route_internal_addr, :seq_id, :work)
      @mux_id, @route_name = opts.values_at(:mux_id, :route_name)# "1.1"
      @loop_once = opts[:loop_once] || false
      @sub_topic = "#{@route_name}/#{@seq_id}"
      @pub_topic = "#{@route_name}/#{@seq_id.next}"
      @collator = {}
    end
    def to_hash
      {:route_name=>@route_name, :seq_id=>@seq_id, :mux_id=>@mux_id, :addr=>@addr}
    end
    def make_sub_socket
      @sub_sock = @route.ctx.socket(ZMQ::SUB)
      @sub_sock.setsockopt(ZMQ::SUBSCRIBE,@sub_topic)
      @sub_sock.connect @addr
    end
    def run(route)
      @route = route
      th = Thread.new do
        make_sub_socket()
        begin
          loop do
            msg = conveyor()
            break if loop_once || (msg && msg.headers[:stop_this_route] == @route_name)
          end
        rescue ZMQ::SocketError => e
          puts "!#{e.inspect}"
        end
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

    def conveyor
      pulled = pull()
      msg,topic = pulled.values_at(:message,:topic)
      #looking for mux_id i.e.:
      #  2.1 total parallel messages 2 & this is the first message
      #  5.5 total 5 & this is the fifth
      #  can arrive in any order

      demux_match = DEMUX_RE.match(topic)
      return push(process(msg)) unless demux_match

      tot,act = demux_match[1,2].map(&:to_i)

      #special case, no demuxing needed for 1.1
      return push(process(msg)) if tot == act && act == 1

      iter = msg.headers[:iter_id]
      # special case, timeout may send a dummy message with mux_id of 2.3 third of 2 messages
      # send messages received so far or this message without merge
      if act > tot
        acc = @collator.delete(:iter)
        return push(process(acc ? acc.message : msg))
      end
      # must be first message
      unless @collator.has_key?(iter)
        @collator[iter] = Accumulator.new(msg,tot)
        return nil
      end

      acc = @collator[iter]
      acc.push msg
      if acc.max?
        @collator.delete(iter)
        return push(process(acc.message))
      end
      nil
    rescue => e
      puts e.message
      puts e.backtrace.inspect
      nil
    end

    def push(msg)
      fpt = @pub_topic + (@mux_id ? "/#{@mux_id}" : "")
      menc = BERT.encode(msg.to_hash)
      @route.publish do |sock|
        sock.send_string(fpt, ZMQ::SNDMORE) #TOPIC
        sock.send_string(menc) #BODY
      end
      puts "->>#{fpt}"
      msg
    rescue => e
      puts e.message
      puts e.backtrace.inspect
    end

    def process(msg)
      m = nil
      begin
        m = work(msg)
      rescue => e
        esrc = @sub_topic
        m = msg.add_to :errors, {:error_source=>esrc, :error_message=>e.message}
      end
      m
    end

    def pull(msg=nil)
      topic = @sub_sock.recv_string
      body  = @sub_sock.more_parts? ? @sub_sock.recv_string : nil
      msg = Lapaz::DefaultMessage.new(body ? BERT.decode(body) : {})
      puts "<<-#{topic}"
      {:message=>msg,:topic=>topic}
    rescue => e
      puts e.message
      puts e.backtrace.inspect
    end

  end
end
