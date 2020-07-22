# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), "dependencies"))

class KineticRequestCeFormRetrieveV1
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
    space_slug = @parameters["space_slug"].empty? ? @info_values["space_slug"] : @parameters["space_slug"]
    if @info_values['api_server'].include?("${space}")
      server = @info_values['api_server'].gsub("${space}", space_slug)
    elsif !space_slug.to_s.empty?
      server = @info_values['api_server']+"/"+space_slug
    else
      server = @info_values['api_server']
    end

    api_username    = URI.encode(@info_values["api_username"])
    api_password    = @info_values["api_password"]
    kapp_slug       = @parameters["kapp_slug"]
    form_slug       = @parameters["form_slug"]
    error_handling  = @parameters["error_handling"]

    api_route = "#{server}/app/api/v1/kapps/#{kapp_slug}/forms/#{form_slug}?include=details,attributes,fields"

    puts "API ROUTE: #{api_route}" if @enable_debug_logging

    resource = RestClient::Resource.new(api_route, { :user => api_username, :password => api_password })

    response = resource.get

    if response.nil?
      <<-RESULTS
      <results>
        <result name="Handler Error Message"></result>
        <result name="Name"></result>
        <result name="Slug"></result>
        <result name="Description"></result>
        <result name="CreatedAt"></result>
        <result name="CreatedBy"></result>
        <result name="UpdatedAt"></result>
        <result name="UpdatedBy"></result>
        <result name="Notes"></result>
        <result name="Secure"></result>
        <result name="Attributes"></result>
        <result name="Fields"></result>
      </results>
      RESULTS
    else
      results = JSON.parse(response)["form"]
      fields = results['fields'].collect { |f| f['name']}
      puts "RESULTS: #{results.inspect}" if @enable_debug_logging
      <<-RESULTS
      <results>
        <result name="Handler Error Message"></result>
        <result name="Name">#{escape(results["name"])}</result>
        <result name="Slug">#{escape(results["slug"])}</result>
        <result name="Description">#{escape(results["description"])}</result>
        <result name="CreatedAt">#{escape(results["createdAt"])}</result>
        <result name="CreatedBy">#{escape(results["createdBy"])}</result>
        <result name="UpdatedAt">#{escape(results["updatedAt"])}</result>
        <result name="UpdatedBy">#{escape(results["updatedBy"])}</result>
        <result name="Notes">#{escape(results["notes"])}</result>
        <result name="Secure">#{escape(results["secure"])}</result>
        <result name="Attributes">#{escape(results["attributes"].to_json)}</result>
        <result name="Fields">#{escape(fields.to_json)}</result>
      </results>
      RESULTS
    end

    rescue RestClient::Exception => error
      error_message = JSON.parse(error.response)["error"]
      if error_handling == "Raise Error"
        raise error_message
      else
        <<-RESULTS
        <results>
          <result name="Handler Error Message">#{error.http_code}: #{escape(error_message)}</result>
        </results>
        RESULTS
      end
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
