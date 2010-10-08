module Lapaz
  require 'usher' unless defined?(Usher)
  class PathHandler
    def initialize(&blk)
      @usher = Usher.new(:delimiters => ['/'])
      instance_eval(&blk) if blk
    end

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
        @unrecognize_block ? @unrecognize_block.call(text) : {:lapaz_path => 'errors/mongrel', :path_params =>{}}
      end
    end
  end
end
