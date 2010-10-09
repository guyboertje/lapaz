require 'singleton'

LapazConfError = Class.new(StandardError)

class LapazConf
  include Singleton
  def initialize
    @nss = Struct.new(:key,:name,:struct,:value)
    @store = {}
  end

  def __slice__(slice)
    @store.store(slice,{}) unless @store.has_key?(slice)
    @_slice = slice
  end

  def method_missing sym, *args, &block
    ret = hash = nil
    save = !!(sym.to_s =~ /.+=$/)
    arg = args.first
    if arg.kind_of?(Hash) #saving the arg
      hash = arg
    end
    if save && hash
      k = hash.keys
      sym = sym.to_s[0..-2]
      cls_name = sym.gsub(/\/(.?)/){"#{$1.upcase}"}.gsub(/(?:^|_)(.)/){$1.upcase} #convert to CamelCase
      sym = sym.to_sym
      ns = @nss.new(sym, cls_name, Struct.new(name,*k))
      ns.value = ns.struct.new(*hash.values_at(*k))
      @store[@_slice][sym] = ns
    end
    if @store[@_slice].has_key?(sym)
      ret = @store[@_slice][sym].value
      block.call(ret) if block
    end
    ret
  end
end

# core extentions

module Kernel
  def lapazcfg(slice='default')
    inst = LapazConf.instance
    inst.__slice__(slice)
    inst
  end
end
