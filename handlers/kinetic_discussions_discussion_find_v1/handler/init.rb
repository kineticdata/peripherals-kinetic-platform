# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class KineticDiscussionsDiscussionFindV1

  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    # Store the info values in a Hash of info names to values.
    @info_values = {}
    REXML::XPath.each(@input_document,"/handler/infos/info") { |item|
      @info_values[item.attributes['name']] = item.text
    }
    @enable_debug_logging = @info_values['enable_debug_logging'] == 'Yes'

    # Store parameters values in a Hash of parameter names to values.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text.to_s
    end
	
	space_slug = @parameters["space_slug"].empty? ? @info_values["space_slug"] : @parameters["space_slug"]
	
	#Set CE Server URL
    if @info_values['ce_server_url'].include?("${space}")
      @ce_server_url = @info_values['ce_server_url'].gsub("${space}", space_slug)
    elsif !space_slug.to_s.empty?
      @ce_server_url = "#{@info_values['ce_server_url'].chomp("/")}/#{space_slug}"
    else
      @ce_server_url = @info_values['ce_server_url'].chomp("/")
    end
	
	#Set Discussion Server URL
    if @info_values['discussions_server_url'].include?("${space}")
      @discussions_api_url = @info_values['discussions_server_url'].gsub("${space}", space_slug).chomp("/") + "/app/discussions/api"
    elsif !space_slug.to_s.empty?
      @discussions_api_url = "#{@info_values['discussions_server_url'].chomp("/")}/#{space_slug}/app/api"
    else
      @discussions_api_url = @info_values['discussions_server_url'].chomp("/")
    end

  end

  def execute
  
    error_handling  = @parameters["error_handling"]
    error_message = nil
	  result = nil
	
    begin
    
      auth_token = get_auth_token

      discussion_search_url = URI.parse("#{@discussions_api_url}/v1/discussions")
      search_query = {}
      search_query['type'] = @parameters['type'] if parameter_not_empty('type')
      search_query['key'] = @parameters['key'] if parameter_not_empty('key')
      search_query['archived'] = @parameters['archived'] if @parameters['archived'].to_s.strip.downcase == "true"
      search_query['start'] = @parameters['start'] if parameter_not_empty('start')
      search_query['end'] = @parameters['end'] if parameter_not_empty('end')
      search_query['title'] = @parameters['title'] if parameter_not_empty('title')
      search_query['limit'] = @parameters['limit'] if /^\d+$/ === @parameters['limit'].to_s.strip
      discussion_search_url.query = URI.encode_www_form(search_query)

      resource = RestClient::Resource.new(discussion_search_url.to_s)
      result = resource.get({ accept: :json, content_type: :json, authorization: "Bearer #{auth_token}" })
	  
    rescue RestClient::Exception => error
      error_message = "#{error.http_code}: #{error.response}"
      raise error_message if error_handling == "Raise Error"
    rescue Exception => error
      error_message = error.inspect
      raise error if error_handling == "Raise Error"
	end
	  

    # Return the results
    return <<-RESULTS
    <results>
	    <result name="Handler Error Message">#{escape(error_message)}</result>
        <result name="Discussions">#{result.nil? ? '' : escape(result.body)}</result>
    </results>
    RESULTS
  end

  ##############################################################################
  # General handler utility functions
  ##############################################################################

  # This is a template method that is used to escape results values (returned in
  # execute) that would cause the XML to be invalid.  This method is not
  # necessary if values do not contain character that have special meaning in
  # XML (&, ", <, and >), however it is a good practice to use it for all return
  # variable results in case the value could include one of those characters in
  # the future.  This method can be copied and reused between handlers.
  def escape(string)
    # Globally replace characters based on the ESCAPE_CHARACTERS constant
    string.to_s.gsub(/[&"><]/) { |special| ESCAPE_CHARACTERS[special] } if string
  end
  # This is a ruby constant that is used by the escape method
  ESCAPE_CHARACTERS = {'&'=>'&amp;', '>'=>'&gt;', '<'=>'&lt;', '"' => '&quot;'}

  def get_auth_token
	oauth_endpoint = "#{@ce_server_url.chomp('/')}/app/oauth/token?grant_type=client_credentials&response_type=token"
    resource = RestClient::Resource.new(oauth_endpoint, user: @info_values['ce_client_id'], password: @info_values['ce_client_secret'])
    result = resource.post({ accept: :json, content_type: :json })
    auth_token = JSON.parse(result)["access_token"]
  end

  def parameter_not_empty(param)
    @parameters[param].to_s.strip.empty? == false
  end

end
