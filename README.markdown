gfront is a frontend app for gollum, a git based ruby wiki library. It basically is a clone of gollum's frontend component, and enhanced some features:

* TOC(Table of Contents) support
* DISQUS comments system
* OpenId login support
* I18n (todo)

### Installation

	$ git clone git@github.com:sjoonk/gfront.git
	$ cd gfront

### Configuration

Open app.rb and edit repo_path and disqus_id as your fit.

### Run

	$ rackup (http://localhost:9292)

That's it.

