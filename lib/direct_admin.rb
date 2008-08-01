# Copyright (c) 2008 Voxxit, LLC
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

module DirectAdmin #:nodoc:
  
  class MissingInformationError < StandardError; end #:nodoc:
  class DirectAdminError < StandardError; end #:nodoc:
  
  # Provides access to DirectAdmin's API
  class Base

    VERSION = "0.1"
    
	  # Defines the required parameters to interface with DA
  	REQUIRED_OPTIONS = {
  	  :base   => [
  	    :username, 
  	    :password, 
  	    :host, 
  	    :failure_email
  	  ],
  	  :do     => [
  	    :command
  	  ]
  	}

  	attr_accessor :username, :password, :host, :ssl, :failure_email

  	# Initializes the DirectAdmin::Base class, setting defaults where necessary.
    # 
    #  da = DirectAdmin::Base.new(options = {})
    #
    # === Example:
    #   da = DirectAdmin::Base.new(:username      => USERNAME,
    #                              :password	    => PASSWORD,
    #                              :host          => HOST,
  	#							                 :ssl           => SSL,
  	#                              :failure_email => FAILURE_EMAIL)
    #
    # === Required options for new
    #   :username       - Your DirectAdmin administrator username
    #   :password       - Your DirectAdmin administrator password
    #   :host           - DirectAdmin's hostname/port
  	#   :failure_email  - E-mail address to send failure messages to
  	#
  	# === Optional options for new
  	#   :ssl            - Enable or disable SSL. Defaults to false!
  	def initialize(options = {})
  	  check_required_options(:base, options)

  	  @username			  = options[:username]
  	  @password			  = options[:password]
  	  @host				    = options[:host]
  	  @ssl				    = options[:ssl]           || false
  	  @failure_email	= options[:failure_email]
  	  
  	end

    # Completes a command on the DirectAdmin server.
    #
    #  > dadmin = DirectAdmin::Base.new(options)
    #  > create = dadmin.do(options = {})
    #
    # === Required options for do
    #   :command      - Command you wish to run on the server. (See: http://directadmin.com/api.html)
    #   :formdata     - Required form data. (See below.)
    #
    # === Example:
    #   create = dadmin.do(:command => "CMD_API_SHOW_ALL_USERS)
    # 
    # === Optional form data
    # In order to complete this command, you may need to supply the
    # following form data as a hash in a POST request, as in the 
    # following example:
    #
    #  form_data = {:action => 'create',
    #               :add => 'Submit',
    #               :username => 'sampleuser',
    #               :email => 'sample@email.com',
    #               :passwd => 'sample_Password',
    #               :passwd2 => 'sample_Password',
    #               :domain => 'sample.com',
    #               :package => 'samplePackage',
    #               :ip => '10.0.0.0',
    #               :notify => 'no'}
    #
    # === Option GET parameters
    # Pass GET parameters (like :user) directly in as options
 
  	def do(options = {})
  	  check_required_options(:do, options)
  	  
  	  @command = options[:command]

      url = URI.parse(@host + @command)
          
      # For GET Requests..
      # Some API actions, like CMD_API_SHOW_USER_DOMAINS must be requested via GET
      if options[:method] == 'get'
        query = ''
        query_string = options.select {|k,v| not %w[command method].include?(k)}
        
        unless query_string.empty?
          query_params = query_string.collect {|k,v| "#{k}=#{v}"}
          query << "?" << query_params.join("&")
        end
        
        req = Net::HTTP::Get.new('/'+ @command + query)
        req.basic_auth @username, @password
        
        response = Net::HTTP.new( url.host, url.port).start {|http| http.request(req) }
      else
        req = Net::HTTP::Post.new(url.path)
        req.basic_auth @username, @password
        
        # For POST requests..
        if options[:formdata]
          req.set_form_data(options[:formdata])
        end
        
        response = Net::HTTP.new(url.host, url.port).start {|http| http.request(req) }
      end
      
      if response
    	  # @response.code = 200 | 404 | 500, etc.
        # @response.body = *text of returned page*
        return response
    	else
    	  raise DirectAdminError.new("Unable to connect to DirectAdmin.")
    	end
  	  
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
        k, v=CGI.unescape(p).split('=',2)
        if cur = params[k]
          if cur.class == Array
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
  
    # Checks the supplied options for a given method or field and throws an exception if anything is missing
    def check_required_options(option_set_name, options = {})
      required_options = REQUIRED_OPTIONS[option_set_name]
      missing = []
      required_options.each{|option| missing << option if options[option].nil?}
      unless missing.empty?
        raise MissingInformationError.new("Missing #{missing.collect{|m| ":#{m}"}.join(', ')}")
      end
    end
  
  end
end