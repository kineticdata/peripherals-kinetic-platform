# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), "dependencies"))

class KineticAgentHandlerExecuteV3
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    # Retrieve all of the handler info values and store them in a hash variable named @info_values.
    @info_values = {}
    REXML::XPath.each(@input_document, "/handler/infos/info") do |item|
      @info_values[item.attributes["name"]] = item.text.to_s.strip
    end

    # Retrieve all of the handler parameters and store them in a hash variable named @parameters.
    @parameters = {}
    REXML::XPath.each(@input_document, "/handler/parameters/parameter") do |item|
      @parameters[item.attributes["name"]] = item.text.to_s.strip
    end

    @enable_debug_logging = @info_values['enable_debug_logging'].downcase == 'yes' ||
                            @info_values['enable_debug_logging'].downcase == 'true'
    puts "Parameters: #{@parameters.inspect}" if @enable_debug_logging
  end

  def execute
    begin
      # Parse Info Values
      api_server      = @info_values["api_server"]
      api_username    = URI.encode(@info_values["api_username"])
      api_password    = @info_values["api_password"]
      # Parse Parameters
      agent_slug      = @parameters["agent_slug"]
      handler_slug    = @parameters["handler_slug"]
      error_handling  = @parameters["error_handling"]
      payload         = @parameters["payload"]
      payload_object  = JSON.parse( payload || "{}")

      if payload_object.has_key?('error_handling') && payload_object['error_handling'] != "Raise Error"
        raise "The parameters passed to the handler executed by Kinetic Agent should set 'error_handling' 
          to 'Raise Error' so that the error is propagated and can be exposed by this handler."
      end

      error_message = nil

      api_route = "#{api_server}/app/components/agents/#{agent_slug}/app/api/v1/handlers/#{handler_slug}/execute"
      puts "API ROUTE: #{api_route}" if @enable_debug_logging
     
      resource = RestClient::Resource.new(api_route, { :user => api_username, :password => api_password })
      
      # Post to the API
      response = resource.post( payload, 
        { :accept => "application/json", :content_type => "application/json" })

      # Parse the response to remove the results wrapper
      response_results = JSON.parse(response)['results'] || {}
      
      # Add the `Handler Error Message` result
      response_results["Handler Error Message"] = ""

      # Build the result strings
      result_strings = response_results.map do |key,value|
        "    <result name=\"#{escape(key)}\">#{escape(value)}</result>"
      end

      return <<-RESULTS
      <results>
      #{result_strings.join("\n")}
      </results>
      RESULTS
      

    # Example:
    #  * 404 (missing handler; use non-existing slug)
    #  * 401/403 (invalid credentials) 
    #  * 400 (malformed body content)
    #  * 400 (calling handler with params that cause error; verify agent handler message bubbles up)
      
    rescue RestClient::Exception => error
      # If the error response body is empty, such as when a 404 is returned
      if error.response.nil?
        error_message = "Agent Response: #{error.http_code} (empty body)"
      elsif error.http_code == 400
        begin
          json = JSON.parse(error.response)
          if json.errorKey = "handler_error"
            error_message = "Agent Handler Error: #{json.errorData.message}"
          else
            error_message = "Agent Response: #{error.http_code} #{error.response}"
          end
        rescue => parse_error
          error_message = "Agent Response: #{error.http_code} #{error.response}"
        end
      else
        error_message = "Agent Response: #{error.http_code} #{error.response}"
      end
      raise error_message if error_handling == "Raise Error"
    rescue Exception => error
      error_message = error.inspect
      raise error if error_handling == "Raise Error"
    end

    # Return the error message if it was caught. Actual results are being returned above if there
    # wasn't a caught error
    return <<-RESULTS
    <results>
      <result name="Handler Error Message">#{escape(error_message)}</result>
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
end
