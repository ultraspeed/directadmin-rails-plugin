module DirectAdmin #:nodoc:
  # Provides access to DirectAdmin's API
  class Base
    attr_accessor :username, :password, :host, :ssl, :failure_email
    
    REQUIRED_OPTIONS = {
      :base => [:username, :password, :host, :failure_email],
      :do => [:command]
    }
    
    # Initializes the DirectAdmin::Base class, setting defaults where necessary.
    #
    # === Example
    #   
    #  da = DirectAdmin::Base.new(
    #    :username => USERNAME,
    #    :password => PASSWORD,
    #    :host => HOST,
    #    :ssl => SSL,
    #    :failure_email => FAILURE_EMAIL
    #  )
    #
    # === Required options
    # * <tt>:username</tt> - DirectAdmin administrator username
    # * <tt>:password</tt> - DirectAdmin administrator password
    # * <tt>:host</tt> - Full DirectAdmin's hostname/port
    # * <tt>:failure_email</tt> - E-mail address to send failure messages to
    #
    # === Optional
    # * <tt>:ssl</tt> - Enable/disable SSL connection to server. Defaults to +false+
    def initialize(options = {})
      check_required_options(:base, options)

      @username = options[:username]
      @password = options[:password]
      @host = options[:host]
      @ssl = options[:ssl] || false
      @failure_email = options[:failure_email]
    end
      	
    # Completes a command on the DirectAdmin server.
    #
    # === Required options
    # * <tt>:command</tt> - Command to run on the server
    # * <tt>:formdata</tt> - Optional form data for command
    #
    # === Example
    #
    #   da.do(
    #     :command => "CMD_API_SHOW_ALL_USERS"
    #   )
    #
    # === Optional form data
    #
    # In order to complete this command, you may need to supply the
    # following form data as a hash in a POST request, as in
    # this example:
    #
    #   form_data = {
    #     :action => 'create',
    #     :add => 'Submit',
    #     :username => 'sampleuser',
    #     :email => 'sample@email.com',
    #     :passwd => 'sample_Password',
    #     :passwd2 => 'sample_Password',
    #     :domain => 'sample.com',
    #     :package => 'samplePackage',
    #     :ip => '10.0.0.0',
    #     :notify => 'no'
    #   }
    #
    # === Option GET parameters
    #
    # Pass GET parameters (like :user) directly in as options
    def do(options = {})
      check_required_options(:do, options)
  
      command = options[:command]
      url = URI.parse(@host + @command)
  
      # For GET Requests..
      # Some API actions, like CMD_API_SHOW_USER_DOMAINS must be requested via GET
      case options[:method]
      when "get"
        query = ''
        query_string = options.select {|k,v| not %w[command method].include?(k)}
    
        unless query_string.empty?
          query_params = query_string.map {|k,v| "#{k}=#{v}"}.join("&")
        end
    
        req = Net::HTTP::Get.new("/#{command}?#{query}")
      else
        req = Net::HTTP::Post.new(url.path)
    
        if options[:formdata]
          req.set_form_data(options[:formdata])
        end
      end
  
      req.basic_auth(@username, @password)
  
      response = Net::HTTP.new(url.host, url.port).start {|http| http.request(req) }
  
      raise DirectAdminError, "Unable to connect to DirectAdmin" if !response
  
      return response
    end

    # Used to parse the response (URL encoded) into a useable hash, if one would like.
    #
    # === Example
    #   @result = @directadmin.parse(@create.body)
    #
    # === Result
    #   { "list[]" => ["user1", "user2", "user3"] }
    def parse(response)
      # Delimiter
      d = "&;"
  
      response = response
  
      params = {}
  
      (response || '').split(/[#{d}] */n).inject(params) { |h,p|
        k,v = CGI.unescape(p).split('=', 2)
    
        if cur = params[k]
          if cur.is_a?(Array)
            params[k] << v  
          else
            params[k] = [cur, v]
          end
        else
          params[k] = v
        end
      }
  
      return params
    end

    private

    # Checks the supplied options for a given method or field
    # and throws an exception if anything is missing
    def check_required_options(option_set_name, options = {})
      required_options = REQUIRED_OPTIONS[option_set_name]
      missing = []
  
      required_options.each do |option|
        missing << option if options[option].nil?
      end
  
      raise MissingInformationError.new("Missing #{missing.collect{|m| ":#{m}"}.join(', ')}") unless missing.empty?
    end
  end
end