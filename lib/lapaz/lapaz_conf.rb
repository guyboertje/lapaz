require 'singleton'

LapazConfError = Class.new(StandardError)

class LapazConf
  include Singleton
  def initialize
    @nss = Struct.new(:key,:name,:struct,:value)
    @envs = {}
    @store = []
  end
  def method_missing sym, *args, &block
    env = :devl
    ret = hash = idx = nil
    save = !!(sym.to_s =~ /.+=$/)
    args.flatten! if args.size == 1 && args.first.kind_of?(Array)
    while !!(arg=args.shift) do
      if arg.kind_of?(Hash) #saving the hash
        hash = arg
      elsif arg.kind_of?(String) || arg.kind_of?(Symbol) #explicit environment
        env = arg.to_sym
      end
    end
    unless @envs.has_key?(env)
      idx = @envs[env] = @store.size
      @store << {}
    end
    idx = @envs[env]
    if save && hash
      k = hash.keys
      sym = sym.to_s[0..-2]
      cls_name = sym.gsub(/\/(.?)/){"#{$1.upcase}"}.gsub(/(?:^|_)(.)/){$1.upcase} #convert to CamelCase
      sym = sym.to_sym
      ns = @nss.new(sym, cls_name, Struct.new(name,*k))
      ns.value = ns.struct.new(*hash.values_at(*k))
      @store[idx][sym] = ns
    end
    if @store[idx].has_key?(sym)
      ret = @store[idx][sym].value
      block.call(ret) if block
    end
    ret
  end
end

# core extentions

module Kernel
  def lapazcfg
    LapazConf.instance
  end
end

class Hash
  def to_struct(name)
    Struct.new(name,*keys).new(*values)
  end
end

