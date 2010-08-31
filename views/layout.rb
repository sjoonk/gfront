class App
  module Views
    class Layout < Mustache
      include Rack::Utils
      alias_method :h, :escape_html

      attr_reader :name, :author

      def title
        "Home"
      end

      def authenticated?
        !!@author
      end
      
      def author_name
        @author.name
      end
      
      def author_email
        @author.email
      end
      
      def gravatar
        Digest::MD5.hexdigest(@author.email)
      end
    end
  end
end
