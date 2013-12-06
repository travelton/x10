$:.unshift File.expand_path("#{File.dirname(__FILE__)}/lib")

require "X10"

map '/' do
  run X10::App
end
