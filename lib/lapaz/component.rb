Thread.abort_on_exception = true

module Lapaz
  class Component
    DEMUX_RE = /.+\/[0-9]+\/([0-9]+)\.([0-9]+)/
    attr_reader :app, :sub_sock, :route_name, :seq_id, :mux_id, :workunit, :loop_once, :name, :pub_to, :pub_at

    def initialize(opts)
      @seq_id, @name, @mux_id, @route_name = opts.values_at(:seq_id, :name, :mux_id, :route_name)
      #puts "#{@route_name} #{@seq_id} >"
      @workunit, @forward_to, @reply_to = opts.values_at(:work, :forward_to, :reply_to)
      @loop_once = opts[:loop_once] || false
      @sub_topic = "#{@route_name}/#{@seq_id}"
      if @forward_to
        route,step,mux = @forward_to.split('/',3)
        @pub_to = route
        @pub_at = step
        @mux_id = mux
      else
        @pub_to = @route_name
        @pub_at = @seq_id.next
      end
      @collator = {}
    end

    def producer?; false; end
    def consumer?; false; end

    def describe
      @name ? {:lapaz_route=>@route_name+"/"+@name} : nil
    end
    def to_hash
      {:route_name=>@route_name, :seq_id=>@seq_id, :mux_id=>@mux_id, :sub_topic=>@sub_topic}
    end
    def make_sub_socket
      sub_sock = lapazcfg.app.ctx.socket(ZMQ::SUB)
      sub_sock.setsockopt(ZMQ::SUBSCRIBE,@sub_topic)
      sub_sock.connect lapazcfg.app.endpt
      sub_sock
    end
    def run(app)
      @app = app
      th = Thread.new do
        sock = make_sub_socket()
        begin
          loop do
            msg = conveyor(sock)
            break if loop_once || (msg && msg.headers[:stop_this_route] == @route_name)
          end
        rescue => e
          puts "???#{to_hash.inspect}"
          puts "!#{e.inspect}"
          puts "backtrace::::: #{e.backtrace}"
        ensure
          sock.close
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

    def conveyor(sock)
      pulled = pull(nil,sock)
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
    end

    def push(msg,q_able=nil)
      if @reply_to && @forward_to
        msg.headers[:reply_to] = @reply_to
      end
      menc = BERT.encode(msg.to_hash)
      q_msg = q_able || Queueable.new(@pub_to,@pub_at,@mux_id)
      puts "component push queueable: #{q_msg.inspect}"
      q_msg.msg = menc
      @app.enqueue(q_msg)
      msg
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

    def pull(msg,sock)
      topic = sock.recv_string
      body  = sock.more_parts? ? sock.recv_string : nil
      msge = Lapaz::DefaultMessage.new(body ? BERT.decode(body) : {}).merge!(msg)
      #puts "<<-#{topic}"
      {:message=>msge,:topic=>topic}
    end


    class Queueable
      attr_reader :route,:name,:mux
      attr_accessor :seq_id,:msg
      def initialize(route,id,mux,msg=nil)
        @route = route
        if id.kind_of?(Integer)
          @seq_id = id
          @name = ''
        else
          @seq_id = 0
          @name = id
        end
        @mux = mux
        @msg = msg
      end
      def named?
        !@name.empty?
      end
      def topic
        a = [@route,@seq_id]
        a << mux if mux && !mux.empty?
        a.join('/')
      end
      def inspect
        "route: #{@route}, name: #{@name}, mux: #{@mux}, seq_id: #{@seq_id}"
      end
    end

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

  end
end

