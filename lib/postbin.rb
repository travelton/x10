require 'pathname'
require 'digest/sha1'
require 'rubygems'
require 'bundler'
Bundler.setup
require 'sinatra/base'
require 'data_mapper'
require 'dm-postgres-adapter'
require 'dm-migrations'
require 'json'
require 'erubis'
require 'net/smtp'

module PostBin
  def self.current_path
    Pathname.new(File.expand_path(File.dirname(__FILE__)))
  end
  
  DataMapper.setup(:default, 'postgres://dqgtksbyewjoon:Llwm4_Cz9CT6S18kO2O0FN2fEp@ec2-23-21-94-137.compute-1.amazonaws.com/d51j3fp8tdd23u')

  Dir[PostBin.current_path + "models/*.rb"].each { |f| require f }
  
  DataMapper.finalize if DataMapper.respond_to?(:finalize)
  DataMapper.auto_upgrade!
  
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
      bin = Bin.new
      url = bin.random_url
      until Bin.first(:url => url).nil?
        url = bin.random_url
      end
      bin.url = url
      bin.created_at = Time.now.to_i
      bin.save!
      redirect bin.url
    end

    get '/cleanup' do
      time_diff = Time.now.to_i - 432000
      @bins = Bin.all(:created_at.lt => time_diff)
      bins_to_dl = Array.new
      items_to_dl = Array.new
      for bin in @bins
        for item in bin.items
          items_to_dl.push(item[:id])
          item.destroy
        end
        bins_to_dl.push(bin[:id])
        bin.destroy
      end
      message = "From: PostBin Cleanup <bot@trstx.com>
      To: Travis Swientek <travis.swientek@rackspace.com>
      Subject: PostBin Cleanup Result

Deleted #{bins_to_dl.length.to_s} bins and #{items_to_dl.length.to_s} items."

      Net::SMTP.start('smtp.mailgun.org', 587, 'trstx.com',
                'postmaster@trstx.com', 'omgpassword', :plain) do |smtp|
        smtp.send_message message, 'travis@trstx.com', 'travis.swientek@rackspace.com'
      end
    end

    get '/:id' do
      @bin = Bin.first(:url => params[:id])
      if not @bin
        erb :error
      else
        erb :show
      end
    end

    post '/:bin_id' do
      bin_it!
    end

    patch '/:bin_id' do
      bin_it!
    end

    def bin_it!
      @bin = Bin.first(:url => params[:bin_id])
      params.delete("bin_id")
      size = params.dup
      if size.to_s.size > 524288
        params.replace({:message => 'Post was too large. Maximum 1MB'})
        @bin.items.create(:params => params.to_json)
        "Too big!"
      else
        @bin.items.create(:params => params.to_json)
        "Got it!"
      end
    end

    def json(v)
      JSON.parse(v).to_json(JSON::State.new(:object_nl => "<br>", :indent => "&nbsp;&nbsp;", :space => "&nbsp;"))
    end

  end
end
