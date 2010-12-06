Thread.abort_on_exception = true

module Lapaz
  class Component
    DEMUX_RE = /.+\/[0-9]+\/([0-9]+)\.([0-9]+)/
    attr_reader :app, :sub_sock, :route_name, :seq_id, :mux_id, :workunit, :loop_once, :name, :pub_to, :pub_at

    def initialize(opts)
      @seq_id, @name, @mux_id, @route_name, @ext = opts.values_at(:seq_id, :name, :mux_id, :route_name, :ext)
      #puts "#{@route_name} #{@seq_id} >"
      @workunit, @forward_to, @reply_to = opts.values_at(:work, :forward_to, :reply_to)
      @loop_once = opts[:loop_once] || false
      @ext = !!(@ext)

      if @forward_to
        if @reply_to && @mux_id
          @reply_to += "/#{@mux_id}"
        end
        route,step,mux = @forward_to.split('/',3)
        @pub_to = route
        @pub_at = step
        @mux_id = mux
      else
        @pub_to = @route_name
        @pub_at = @seq_id.next
      end
      @collator = {}
      @endpt = lapazcfg.app.endpt
      @ctx = lapazcfg.app.ctx
      @sub_topic = lapazcfg.app.topic_base + "#{@route_name}/#{@seq_id}"
    end

    def producer?; false; end
    def consumer?; false; end

    def describe(external_only=false)
      return nil unless @name
      return nil unless @ext
      {:lapaz_route=>{:path=>"#{@route_name}/#{@name}", :externally_callable=>@ext}}
    end
    def to_hash
      {:route_name=>@route_name, :seq_id=>@seq_id, :mux_id=>@mux_id, :sub_topic=>@sub_topic}
    end
    def run(app)
      @app = app
      Thread.new do
        trans = ZeroMqSub.new(@ctx,@endpt)
        trans.subscribe(@sub_topic)
        begin
          loop do
            msg = conveyor(trans)
            break if loop_once || (msg && msg.headers[:stop_this_route] == @route_name)
          end
        rescue => e
          puts "???#{to_hash.inspect}"
          puts "!#{e.inspect}"
          puts "backtrace::::: #{e.backtrace}"
        ensure
          trans.close
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

    def conveyor(trans)
      pulled = pull(nil,trans)
      msg,topic = pulled.values_at(:message,:topic)
      #looking for mux_id i.e.:
      #  2.1 means accumulate 2 messages& this is the first message
      #  5.5 means accumulate 5 & this is the fifth
      #  can arrive in any order
      #  message acculate keyed by iteration id

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
      return nil unless msg

      if @reply_to
        msg.add_reply_to @reply_to
      end
      q_msg = q_able || Queueable.new(@pub_to,@pub_at,@mux_id)
      #puts "component push queueable: #{q_msg.inspect}"
      #puts "msg: #{msg.inspect}"
      q_msg.msg = DefCoder.encode(msg.to_hash)
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

    def pull(msg,trans)
      topic,body = trans.receive
      msge = Lapaz::Message.new(body ? DefCoder.decode(body) : {}).merge!(msg)
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
      def ext_route
        "#{route}/#{name}"
      end
      def topic
        a = [route]
        a << seq_id if seq_id && seq_id > -1
        a << mux if mux && !mux.empty?
        a.join('/')
      end
      def inspect
        "route: #{@route}, name: #{@name}, mux: #{@mux}, seq_id: #{@seq_id}, msg: #{@msg.inspect}"
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

