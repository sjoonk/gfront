require 'sinatra/base'
require 'gollum'
# require 'mustache/sinatra'
require 'rack/openid'
require 'hashie/mash'
require 'lib/helper'
require 'lib/auth_helper'
require 'lib/page_helper'
# require 'lib/open_id_auth'

class App < Sinatra::Base

  # Set your own git repository path and disqus_id here
  # set :repo_path, "YOUR_REPO_PATH" 
  set :repo_path, "/Users/coti22/Wikis/my-gollum-repo"
  set :disqus_id, "gov20wiki"

  # register Mustache::Sinatra
  # require 'views/layout'
  # require 'views/editable'
  # set :mustache, {
  #   :templates => "#{dir}/templates",
  #   :views => "#{dir}/views"
  # }

  # If you need to set additional parameters for sessions, like expiration date, 
  # use Rack::Session::Cookie directly instead of enable :sessions
  # enable :sessions

  # Session needs to be before Rack::OpenID
  use Rack::Session::Cookie
  use Rack::OpenID

  dir = File.dirname(File.expand_path(__FILE__))

  set :public, "#{dir}/public"
  enable :static # syntactic sugar of set :static, true

  # Sinatra error handling
  configure :development, :staging do
    set :raise_errors, false
    set :show_exceptions, true
    set :dump_errors, true
    set :clean_trace, false
  end

  helpers Helper, AuthHelper, PageHelper

  before do
    @author = session[:author] ? Hashie::Mash[session[:author]] : nil
  end

  get '/' do
    show_page_or_file('Home')
  end


  get '/login' do
    erb :login
  end

  post '/login' do
    # TODO: validation and refactoring
    pass if params[:openid_identifier]
    session[:author] = {
      :name => params[:name],
      :email => params[:email]
    }
    redirect session[:return_to]
  end

  post '/login' do
    if resp = request.env["rack.openid.response"]
      if resp.status == :success
        sreg = OpenID::SReg::Response.from_success_response(resp)
        session[:author] = {
          :name => sreg.data["fullname"] || sreg.data["nickname"],
          :email => sreg.data["email"]
        }
        redirect session[:return_to]
      else
        "Error: #{resp.status}"
      end
    else
      headers 'WWW-Authenticate' => Rack::OpenID.build_header(
        :identifier => params["openid_identifier"], 
        :required => [:nickname, :email],
        :optional => :fullname
      )
      throw :halt, [401, 'got openid?']
    end
  end
  
  get '/logout' do
    session.delete(:author)
    redirect '/'
  end  

  get '/edit/:name' do
    login_required
    @name = params[:name]
    wiki = Gollum::Wiki.new(settings.repo_path)
    if page = wiki.page(@name)
      @page = page
      @content = page.raw_data
      @formats = formats
      erb :edit
    else
      @formats = formats(:markdown)
      raise @formats.inspect
      erb :create
    end
  end

  post '/edit/:name' do
    login_required
    name   = params[:name]
    wiki   = Gollum::Wiki.new(settings.repo_path)
    page   = wiki.page(name)
    format = params[:format].intern
    name   = params[:rename] if params[:rename]
    wiki.update_page(page, name, format, params[:content], commit_message)
    redirect "/#{Gollum::Page.cname name}"
  end

  post '/create/:name' do
    login_required
    name = params[:page]
    wiki = Gollum::Wiki.new(settings.repo_path)
    format = params[:format].intern
    begin
      wiki.write_page(name, format, params[:content], commit_message)
      redirect "/#{name}"
    rescue Gollum::DuplicatePageError => e
      @message = "Duplicate page: #{e.message}"
      erb :error
    end
  end

  post '/preview' do
    format = params['wiki_format']
    data = params['text']
    wiki = Gollum::Wiki.new(settings.repo_path)
    wiki.preview_page("Preview", data, format).formatted_data
  end

  get '/history/:name' do
    @name     = params[:name]
    wiki      = Gollum::Wiki.new(settings.repo_path)
    @page     = wiki.page(@name)
    @page_num = [params[:page].to_i, 1].max
    @versions = @page.versions :page => @page_num
    erb :history
  end

  post '/compare/:name' do
    @versions = params[:versions] || []
    if @versions.size < 2
      redirect "/history/#{params[:name]}"
    else
      redirect "/compare/%s/%s...%s" % [
        params[:name],
        @versions.last,
        @versions.first]
    end
  end

  get '/compare/:name/:version_list' do
    @name     = params[:name]
    @versions = params[:version_list].split(/\.{2,3}/)
    wiki      = Gollum::Wiki.new(settings.repo_path)
    @page     = wiki.page(@name)
    # diffs     = wiki.repo.diff(@versions.first, @versions.last, @page.path) # Not working with multibyte name
    diffs     = wiki.repo.diff(@versions.first, @versions.last)
    @diff     = diffs.first
    erb :compare
  end

  get %r{/(.+?)/([0-9a-f]{40})} do
    name = params[:captures][0]
    wiki = Gollum::Wiki.new(settings.repo_path)
    if page = wiki.page(name, params[:captures][1])
      @page = page
      @name = name
      @content = page.formatted_data
      erb :page
    else
      halt 404
    end
  end

  get '/*' do
    show_page_or_file(params[:splat].first)
  end

  def show_page_or_file(name)
    wiki = Gollum::Wiki.new(settings.repo_path)
    if page = wiki.page(name)
      @page = page
      @name = name
      @content = page.formatted_data
      erb :page
    elsif file = wiki.file(name)
      file.raw_data
    else
      @name = name
      @formats = formats(:markdown)
      erb :create
    end
  end

  def commit_message
    { :message => params[:message], 
      :name => @author ? @author.name : (params[:author_name] ? params[:author_name].strip : '(anonymous)'),
      :email => @author ? @author.email : (params[:author_email] ? params[:author_name].strip : 'anon@anon.com')
    }
    # { :message => params[:message],
    #   :name    => `git config --get user.name `.strip,
    #   :email   => `git config --get user.email`.strip }
  end
end
