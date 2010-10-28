module Lapaz
  require 'usher' unless defined?(Usher)
  class PathHandler

    include Blockenspiel::DSL
#:delimiters => ['/','.']
    def initialize(&blk)
      @usher = Usher.new()
      instance_eval(&blk) if blk
    end

    dsl_methods false

    def handle(request_path)
      response = @usher.recognize_path(request_path.strip)
      if response
        ret = response.path.route.destination.dup
        blk = ret.delete(:block)
        ret[:path_params] = response.params.inject({}){|h,(k,v)| h[k]=v; h}
        if blk
          blk.call(ret)
        else
          #puts "handler found: #{ret.inspect}"
          ret
        end
      else
        @unrecognize_block ? @unrecognize_block.call : {:lapaz_path => 'errors/mongrel', :path_params =>{}}
      end
    end

    dsl_methods true

    def unrecognized(&blk)
      @unrecognize_block = blk
    end

    def build(opts = nil, &blk)
      o = opts.dup
      url_pattern = o.delete(:url_pattern)
      o[:view_template] ||= ''
      o[:view_layout] ||= ''
      o[:block] = blk
      @usher.add_route(url_pattern).to(o)
    end

  end
end
