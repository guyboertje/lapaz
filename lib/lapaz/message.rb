module Lapaz
  class Message
    attr_accessor :body, :headers, :errors, :warnings
    attr_reader :kind
    def initialize(opts={})
      @headers = opts[:headers] || {}
      @body = opts[:body] || {}
      @errors = opts[:errors] || []
      @warnings = opts[:warnings] || []
      @kind = opts[:kind] || "base"
    end
    def has_header_key?(key)
      headers.has_key? key
    end
    def has_body_key?(key)
      body.has_key? key
    end
    def add_to(where, what)
      case where
      when :headers
        @headers.merge! what
      when :body
        @body.merge! what
      when :errors
        @errors << what
      when :warnings
        @warnings << what
      end
      self
    end
    alias :add :add_to

    def merge!(message)
      return self unless message
      @headers.merge! message.headers
      @body.merge! message.body
      @errors += message.errors
      @warnings += message.warnings
      self
    end

    def to_hash
      {:kind=>kind,:headers=>headers,:body=>body,:errors=>errors,:warnings=>warnings}
    end
    def inspect
      to_hash.inspect
    end
  end

  class DefaultMessage < Message
    def initialize(opts={})
      opts[:kind] = 'default'
      super
    end
  end

  class MongrelMessage < Message
    def initialize(opts={})
      e = []
      e << "Argument Error: no sender_id given" unless opts[:sender]
      e << "Argument Error: no conn_id given" unless opts[:conn_id]
      e << "Argument Error: no path given" unless opts[:path]
      h = opts.delete(:headers)
      b = opts.delete(:body)

      h.merge!(opts)
      super({:kind=>'mongrel2',:headers=>h,:errors=>e,:body=>{:mongrel_req_body=>b}})
    end
  end
end
