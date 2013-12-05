require 'pathname'
require 'digest/sha1'
require 'rubygems'
require 'bundler'
Bundler.setup
require 'sinatra/base'
require 'data_mapper'
require 'dm-mysql-adapter'
require 'dm-migrations'
require 'json'
require 'erubis'
require 'net/smtp'

module PostBin
  def self.current_path
    Pathname.new(File.expand_path(File.dirname(__FILE__)))
  end
  
  DataMapper.setup(:default, 'mysql://dqgtksbyewjoon:Llwm4_Cz9CT6S18kO2O0FN2fEp@162.209.114.172/d51j3fp8tdd23u')

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
    
  #Default Handler

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

    #API Handlers

    get '/api/new' do
      bin = Bin.new
      url = bin.random_url
      until Bin.first(:url => url).nil?
        url = bin.random_url
      end
      bin.url = url
      bin.created_at = Time.now.to_i
      bin.save!
      content_type :json
      {:url => "http://#{request.env['HTTP_HOST']}/api/#{bin.url}"}.to_json
    end

    get '/api/:id' do
      @bin = Bin.first(:url => params[:id])
      if not @bin
        content_type :json
        {:message => 'Sorry, Bin has expired or deleted. Create a new one.'}.to_json
      else
        content_type :json
        @bin.items.to_json
      end
    end

    delete '/api/:id' do
      @bin = Bin.first(:url => params[:id])
      for item in @bin.items
          item.destroy!
      end
      @bin.destroy!
      content_type :json
      {:message => "Bin #{@bin.url} deleted"}.to_json
    end

    get '/:id' do
      @bin = Bin.first(:url => params[:id])
      if not @bin
        @message = "Sorry, couldn't find that PostBin, create a new one."
        erb :error
      else
        erb :show
      end
    end

    #Web Handlers

    post '/:bin_id' do
      bin_it!
    end

    post '/api/:bin_id' do
      bin_it!
    end

    post '/:bin_id/*' do
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      endpoint = params[:splat][0]
      params.delete("splat")
      params.merge!({:endpoint => endpoint})
      bin_it!
    end

    get '/utils/stats' do
      item_count = Item.count()
      bin_count = Bin.count()
      total_rows = item_count + bin_count
      content_type :json
      {:total_bins => bin_count, :total_items => item_count, :total_rows => total_rows}.to_json
    end

    patch '/:bin_id' do
      bin_it!
    end

    get '/:id/delete' do
      @bin = Bin.first(:url => params[:id])
      for item in @bin.items
          item.destroy!
      end
      if @bin.destroy!
        redirect '/'
      else 
        "Oops, error deleting. Email support@mailgunhq.com and we'll fix it."
      end
    end

    #Cleanup Handler

    get '/utils/cleanup' do
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

    def bin_it!
      if @auth && @auth.provided? && @auth.basic? && @auth.credentials
        pass_replace = @auth.credentials[1].slice! 0..4
        pass_replace.concat("********* (Hidden)")
        params.merge!({:username => @auth.credentials[0], :password => pass_replace})
      end
      @bin = Bin.first(:url => params[:bin_id])
      bin_count = @bin.items.count()
      if bin_count == 20
        params.replace({:message => 'Bin exceeded maximum posts. Create a new bin.'})
        @bin.items.create(:params => params.to_json, :created_at => Time.now.to_i)
        content_type :json
        return {:message => 'Too many posts. Create a new bin!'}.to_json
      elsif bin_count > 20
        content_type :json
        return {:message => 'Too many posts. Create a new bin!'}.to_json
      end

      params.delete("bin_id")
      size = params.dup

      if size.to_s.size > 524288
        params.replace({:message => 'Post was too large. Maximum 1MB'})
        @bin.items.create(:params => params.to_json, :created_at => Time.now.to_i)
        content_type :json
        return {:message => 'Post too large. Try again!'}.to_json
      else
        @bin.items.create(:params => params.to_json, :created_at => Time.now.to_i)
        return {:message => 'Post received. Thanks!'}.to_json
      end
    end

    def json(v)
      JSON.parse(v).to_json(JSON::State.new(:object_nl => "<br>", :indent => "&nbsp;&nbsp;", :space => "&nbsp;"))
    end

  end
end
