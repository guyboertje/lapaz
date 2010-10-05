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
      url_pattern, lapaz_route = opts.values_at(:url_pattern, :lapaz_route)
      @usher.add_route(url_pattern).to(:lapaz => lapaz_route, :block => blk)
    end

    def handle(request_path)
      response = @usher.recognize_path(request_path.strip)
      if response
        blk = response.path.route.destination[:block]
        lap = response.path.route.destination[:lapaz]
        prm = response.params.inject({}){|h,(k,v)| h[k]=v; h}
        ret = {:lapaz_path => lap, :path_params =>prm}
        if blk
          blk.call(ret)
        else
          puts "handler found: #{ret.inspect}"
          ret
        end
      else
        @unrecognize_block ? @unrecognize_block.call(text) : {:lapaz_path => 'errors/mongrel', :path_params =>{}}
      end
    end
  end
end
