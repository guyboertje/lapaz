requires = %W(request connection)
requires.each do |lib|
  require File.join('m2r',lib)
end
requires = %W(serializer mongo message component producer consumer processor router path_handler)
requires.each do |lib|
  require File.join('lapaz',lib)
end

#require 'eip'
#require 'filter'
