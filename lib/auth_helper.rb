module AuthHelper

  def authenticated?
    !!@author
  end
  
  def gravatar
    Digest::MD5.hexdigest(@author.email)
  end

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