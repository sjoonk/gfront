require 'rubygems'
require 'sinatra/base'
require 'gollum'
require 'mustache/sinatra'
require 'rack/openid'
require 'hashie/mash'

class App < Sinatra::Base
  register Mustache::Sinatra
  require 'views/layout'
  require 'views/editable'

  # If you need to set additional parameters for sessions, like expiration date, 
  # use Rack::Session::Cookie directly instead of enable :sessions
  # enable :sessions

  # Session needs to be before Rack::OpenID
  use Rack::Session::Cookie
  use Rack::OpenID

  dir = File.dirname(File.expand_path(__FILE__))

  # Set your own git repository path here
  # set :repo_path, "YOUR_REPO_PATH" 
  set :repo_path, "/Users/coti22/Wikis/my-gollum-repo"
  # set :disqus_id, "gov20wiki"
  # DISQUS_ID = 'gov20wiki'

  set :public, "#{dir}/public"
  set :static, true

  set :mustache, {
    :templates => "#{dir}/templates",
    :views => "#{dir}/views"
  }

  # Sinatra error handling
  configure :development, :staging do
    set :raise_errors, false
    set :show_exceptions, true
    set :dump_errors, true
    set :clean_trace, false
  end

  # helpers do
  #   def authenticated?
  #     !!session[:author]
  #   end
  # end

  helpers do
    # Not used yet
    def login_required
      if session[:author]
        return true
      else
        session[:return_to] = request.fullpath
        redirect '/login'
        return false
      end
    end
  end
    
  before do
    @author = session[:author] ? Hashie::Mash[session[:author]] : nil
  end

  get '/' do
    show_page_or_file('Home')
  end

  get '/login' do
    mustache :login
  end

  post '/login' do
    if resp = request.env["rack.openid.response"]
      if resp.status == :success
        sreg = OpenID::SReg::Response.from_success_response(resp)
        session[:author] = {
          :name => sreg.data["fullname"] || sreg.data["nickname"],
          :email => sreg.data["email"]
        }
        redirect '/' #session[:return_to]
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
    @name = params[:name]
    wiki = Gollum::Wiki.new(settings.repo_path)
    if page = wiki.page(@name)
      @page = page
      @content = page.raw_data
      mustache :edit
    else
      mustache :create
    end
  end

  post '/edit/:name' do
    name   = params[:name]
    wiki   = Gollum::Wiki.new(settings.repo_path)
    page   = wiki.page(name)
    format = params[:format].intern
    name   = params[:rename] if params[:rename]

    wiki.update_page(page, name, format, params[:content], commit_message)

    redirect "/#{Gollum::Page.cname name}"
  end

  post '/create/:name' do
    name = params[:page]
    wiki = Gollum::Wiki.new(settings.repo_path)

    format = params[:format].intern

    begin
      wiki.write_page(name, format, params[:content], commit_message)
      redirect "/#{name}"
    rescue Gollum::DuplicatePageError => e
      @message = "Duplicate page: #{e.message}"
      mustache :error
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
    mustache :history
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
  
  # "\353\202\264\354\235\274-\355\225\264\354\225\274\355\225\240-\354\213\234\353\217\204\353\223\244"
  # "\353\202\264\354\235\274-\355\225\264\354\225\274\355\225\240-\354\213\234\353\217\204\353\223\244"
  # {"name"=>"Home", "version_list"=>"f000bfbba7f13be1aa1b36a81f94b7b14b799542...ecfee441c5e2fc679dacd59fbc7d3ce051d73fd6"}

  get '/compare/:name/:version_list' do
    @name     = params[:name]
    @versions = params[:version_list].split(/\.{2,3}/)
    wiki      = Gollum::Wiki.new(settings.repo_path)
    @page     = wiki.page(@name)
    # diffs     = wiki.repo.diff(@versions.first, @versions.last, @page.path) # Not working with multibyte name
    diffs     = wiki.repo.diff(@versions.first, @versions.last)
    @diff     = diffs.first
    mustache :compare
  end

  get %r{/(.+?)/([0-9a-f]{40})} do
    name = params[:captures][0]
    wiki = Gollum::Wiki.new(settings.repo_path)
    if page = wiki.page(name, params[:captures][1])
      @page = page
      @name = name
      @content = page.formatted_data
      mustache :page
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
      mustache :page
    elsif file = wiki.file(name)
      file.raw_data
    else
      @name = name
      mustache :create
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
