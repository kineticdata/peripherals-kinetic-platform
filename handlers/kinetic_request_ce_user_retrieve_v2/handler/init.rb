# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), "dependencies"))

class KineticRequestCeUserRetrieveV2
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
    username        = URI.encode(@parameters["username"])
    error_handling  = @parameters["error_handling"]

    api_route = "#{server}/app/api/v1/users/#{username}?include=details,attributes,profileAttributes,memberships"

    resource = RestClient::Resource.new(api_route, { :user => api_username, :password => api_password })

    response = resource.get

    if response.nil?
      <<-RESULTS
      <results>
        <result name="Handler Error Message"></result>
        <result name="Username"></result>
        <result name="Display Name"></result>
        <result name="Email"></result>
        <result name="Created At"></result>
        <result name="Created By"></result>
        <result name="Enabled"></result>
        <result name="Updated At"></result>
        <result name="Updated By"></result>
        <result name="Preferred Locale"></result>
        <result name="Attributes"></result>
        <result name="Profile Attributes"></result>
		    <result name="Memberships"></result>
        <result name="Exists">false</result>
      </results>
      RESULTS
    else
      user = JSON.parse(response)["user"]
      <<-RESULTS
      <results>
        <result name="Handler Error Message"></result>
        <result name="Username">#{escape(user["username"])}</result>
        <result name="Display Name">#{escape(user["displayName"])}</result>
        <result name="Email">#{escape(user["email"])}</result>
        <result name="Created At">#{escape(user["createdAt"])}</result>
        <result name="Created By">#{escape(user["createdBy"])}</result>
        <result name="Enabled">#{escape(user["enabled"])}</result>
        <result name="Updated At">#{escape(user["updatedAt"])}</result>
        <result name="Updated By">#{escape(user["updatedBy"])}</result>
        <result name="Preferred Locale">#{escape(user["preferredLocale"])}</result>
        <result name="Attributes">#{escape(user["attributes"].to_json)}</result>
        <result name="Profile Attributes">#{escape(user["profileAttributes"].to_json)}</result>
		    <result name="Memberships">#{escape(user["memberships"].to_json)}</result>
        <result name="Exists">true</result>
      </results>
      RESULTS
    end

  	rescue RestClient::Exception => error
      error_message = JSON.parse(error.response)["error"]
      if error_handling == "Raise Error"
        raise error_message
      else
        if error.http_code == 404
          <<-RESULTS
          <results>
            <result name="Exists">false</result>
            <result name="Handler Error Message"></result>
          </results>
          RESULTS
        else
          <<-RESULTS
          <results>
            <result name="Handler Error Message">#{error.http_code}: #{escape(error_message)}</result>
          </results>
          RESULTS
        end
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
