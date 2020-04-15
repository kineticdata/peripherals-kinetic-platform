# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), "dependencies"))

class KineticAgentHandlerExecuteV1
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
      api_username    = URI.encode(@info_values["api_username"])
      api_password    = @info_values["api_password"]
      server = @info_values["api_server"]
      error_handling  = @parameters["error_handling"]
      error_message = nil

      api_route = "#{server}/#{@parameters['handler_space']}/app/api/v1/handlers/#{@parameters["handler_slug"]}/execute"
      puts "API ROUTE: #{api_route}" if @enable_debug_logging

      resource = RestClient::Resource.new(api_route, { :user => api_username, :password => api_password })

      # Post to the API
      response = resource.post(@parameters['payload'], { :accept => "json", :content_type => "json" })

      puts "RESULTS: #{response.inspect}" if @enable_debug_logging
      return <<-RESULTS
      <results>
        <result name="Handler Error Message"></result>
        <result name="output">#{escape(response)}</result>
      </results>
      RESULTS

    rescue RestClient::Exception => error
      begin
        error_message = "#{error.http_code}: #{JSON.parse(error.response)["error"]}"
      rescue
        error_message = error.inspect
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
