module Lapaz
  module OrderedArray
    def <<(val)
      self[next_key] = val
    end
    def ordered_array
      true
    end
    def concat!(val)
      if val.kind_of?(Hash)
        val.values.each do |v|
          self[next_key] = v
         end
      elsif val.kind_of?(Array)
        val.each do |v|
          self[next_key] = v
        end
      else
        self[next_key] = val
      end
    end
    def pop
      self.delete(keys.sort_by(&:to_s).last)
    end
    def last
      self[keys.sort_by(&:to_s).last]
    end
    def first
      self[keys.sort_by(&:to_s).first]
    end
    private
    def next_key
      keys.empty? ? :__aa : keys.sort_by(&:to_s).last.to_s.next.to_sym
    end
  end

  class Message
    attr_accessor :body, :errors, :warnings, :headers
    attr_reader :kind

    def self.new_keep_headers(msg)
      new({:kind=>msg.kind,:headers=>msg.headers})
    end

    def initialize(opts={})

      hdrs = opts[:headers] || {}
      if reply_to = hdrs[:reply_to]
        nrt, ort = nil, reply_to
        if reply_to.kind_of?(Hash)
          if reply_to.has_key?(:__aa)
            reply_to.extend(OrderedArray) unless reply_to.respond_to?(:ordered_array)
          else
            ort = reply_to.dup
            nrt = {}
            nrt.extend(OrderedArray)
          end
        else
          nrt = {}
          nrt.extend(OrderedArray)
        end
        if nrt
          nrt << ort
          hdrs[:reply_to] = nrt
        end
      end
      @headers= hdrs
      @body = opts[:body] || {}
      @errors = opts[:errors] || []
      @warnings = opts[:warnings] || []
      @kind = opts[:kind] || "base"
    end

    def add_iteration_id
      @headers[:iter_id] = ::UUID.generate
    end

    def add_reply_to(val)
      if @headers[:reply_to].nil?
        h = {}
        h.extend(OrderedArray)
        @headers[:reply_to] = h
      end
      @headers[:reply_to] << val
    end

    def fetch(*h_path)
      obj = nil
      key = h_path.shift
      obj = @headers if key.to_s.start_with?('head')
      obj = @body if key.to_s.start_with?('body')
      while obj && h_path.size > 0
        key = h_path.shift
        obj = obj[key]
      end
      obj
    end

    def has_header_key?(key)
      @headers.has_key? key
    end

    def has_body_key?(key)
      body.has_key? key
    end

    def replace(where, what)
      case where
      when :body
        @body = what
      when :errors
        @errors = what
      when :warnings
        @warnings = what
      end
      self
    end

    def add_to(where, what)
      case where
      when :headers,:header
        @headers.merge!(what) do |k,ov,nv|
          deeper_merge(ov,nv)
        end
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
      @headers.merge!(message.headers) do |k,ov,nv|
        deeper_merge(ov,nv)#
      end
      @body.merge! message.body
      @errors += message.errors
      @warnings += message.warnings
      self
    end

    def to_hash
      {:kind=>kind,:headers=>headers,:body=>body,:errors=>errors,:warnings=>warnings}
    end
    def to_hash_content
      {:kind=>kind,:body=>body,:errors=>errors,:warnings=>warnings}
    end
    def to_json
      to_hash.to_json
    end
    def to_json_content
      to_hash_content.to_json
    end
    def inspect
      to_hash.inspect
    end
    private
    def deeper_merge(old_val,new_val)
      if old_val.kind_of?(Hash) && new_val.kind_of?(Hash)
        if old_val.respond_to?(:ordered_array)
          old_val.concat!(new_val)
        else
          old_val.merge!(new_val)
        end
        old_val
      elsif old_val.kind_of?(Array) && new_val.kind_of?(Array)
        old_val.concat(new_val).uniq!
        old_val
      else
        new_val
      end
    end
  end

  class DefaultMessage < Message
    def initialize(opts={})
      opts[:kind] = 'default'
      super
    end
  end

  class McastMessage < Message
    def initialize(opts={})
      opts[:kind] = 'multicast'
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
