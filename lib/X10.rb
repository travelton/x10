require 'pathname'
require 'digest/sha1'
require 'rubygems'
require 'bundler'
Bundler.setup
require 'sinatra/base'
require 'erubis'

module X10
  class App < Sinatra::Base
    configure do
      set :logging, Proc.new { !test? }
      set :static, true
    end

    helpers do
      include Rack::Utils
      alias_method :h, :escape_html
    end

    get '/' do
      "Hello"
    end
    
    get '/:id/:status' do
      exec("bash /etc/cm19a/run.sh #{:id} #{:status}")
    end
  end
end
