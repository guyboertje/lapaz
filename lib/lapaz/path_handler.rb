module Lapaz
  require 'usher' unless defined?(Usher)
  class PathHandler

    include Blockenspiel::DSL

    def initialize(&blk)
      @usher = Usher.new()
      instance_eval(&blk) if blk
    end

    dsl_methods false

    def handle(request_path)
      stripped = request_path.strip
      response = @usher.recognize_path(stripped)
      if response
        ret = response.path.route.destination.dup
        blk = ret.delete(:block)
        ret[:path_params] = response.params.inject({}){|h,(k,v)| h[k]=v; h} if response.params
        if blk
          blk.call(ret)
        else
          #puts "handler found: #{ret.inspect}"
          ret
        end
      else
        @unrecognize_block ? @unrecognize_block.call(stripped) : {:lapaz_path=>'errors/mongrel', :path_params=>[{}]}
      end
    end

    dsl_methods true

    def unrecognized(&blk)
      @unrecognize_block = blk
    end

    def build(opts = nil, &blk)
      o = opts.dup
      url_pattern = o.delete(:path_pattern)
      o[:block] = blk
      @usher.add_route(url_pattern).to(o)
    end

  end
end
