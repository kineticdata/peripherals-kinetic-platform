# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), "dependencies"))

class KineticRequestCeUserUpdateV3
  # Prepare for execution by building Hash objects for necessary values and
  # validating the present state.  This method sets the following instance
  # variables:
  # * @input_document - A REXML::Document object that represents the input Xml.
  # * @info_values - A Hash of info names to info values.
  # * @parameters - A Hash of parameter names to parameter values.
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Parameters
  # * +input+ - The String of Xml that was built by evaluating the node.xml
  #   handler template.
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
  end

  # The execute method gets called by the task engine when the handler's node is processed. It is
  # responsible for performing whatever action the name indicates.
  # If it returns a result, it will be in a special XML format that the task engine expects. These
  # results will then be available to subsequent tasks in the process.
  def execute
    api_username      = URI.encode(@info_values["api_username"])
    api_password      = @info_values["api_password"]
    api_server        = @info_values["api_server"]
    space_slug        = @parameters["space_slug"].empty? ? @info_values["space_slug"] : @parameters["space_slug"]
    current_username  = URI.encode(@parameters["current_username"])
    error_handling  = @parameters["error_handling"]

    api_route = "#{api_server}/#{space_slug}/app/api/v1/users/#{current_username}?include=details,attributes,profileAttributes"

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
        <result name="Attributes"></result>
      </results>
      RESULTS
    else
      # Start Update Code
      api_route = "#{api_server}/#{space_slug}/app/api/v1/users/#{current_username}"
      resource = RestClient::Resource.new(api_route, { :user => api_username, :password => api_password })
      enabled = boolean(@parameters["enabled"])
      space_admin = boolean(@parameters["space_admin"])
      user = JSON.parse(response)["user"]

      # If Attributes are to be appended to exisiting attributes
      if @parameters["append_or_replace"]=="Append"
        # If new attributes are supplied process the values
        if !@parameters["attributes"].empty?
          current_attributes = user["attributes"]
          new_attributes = JSON.parse(@parameters["attributes"])
          # Iterate through each new attributes
          new_attributes.each do |new|
            # Initialize a value to assume no match was found
            match = false
            # Iterate through each currents attributes
            current_attributes.each do |current|
              # If the new attribute already exists continue
              if current['name'] == new['name']
                # Set flag to indicate the attribute exist in current list
                match = true
                # Iterate through each of the attributes values to check if it already exists
                new['values'].each do |value|
                  # If the value doesn't already exist in attributes, add it
                  if !current['values'].include? value
                    current['values'].push(value)
                  end
                end
              end


            end
            # If the attribute didn't exist add its values.
            if !match
              user["attributes"].push(new)
            end
          end
        end

        # If new Profile Attributes are supplied process the values and Profile Attriubutes exist (version 1.1 and higher)
        if !@parameters["profile_attributes"].empty? && !user["profileAttributes"].nil?
          current_profile_attributes = user["profileAttributes"]
          new_profile_attributes = JSON.parse(@parameters["profile_attributes"])
          # Iterate through each new Profile Attributes
          new_profile_attributes.each do |new|
            # Initialize a value to assume no match was found
            match = false
            # Iterate through each currents Profile Attributes
            current_profile_attributes.each do |current|
              # If the new attribute already exists continue
              if current['name'] == new['name']
                # Set flag to indicate the attribute exist in current list
                match = true
                # Iterate through each of the Profile Attributes values to check if it already exists
                new['values'].each do |value|
                  # If the value doesn't already exist in Profile Attributes, add it
                  if !current['values'].include? value
                    current['values'].push(value)
                  end
                end
              end


            end
            # If the attribute didn't exist add its values.
            if !match
              user["profileAttributes"].push(new)
            end
          end
        end
      # Else Replace Attributes with existing Attributes
      else
        user["attributes"] = JSON.parse(@parameters["attributes"])
        user["profileAttributes"] = JSON.parse(@parameters["profile_attributes"])
      end

      data = {}
      data.tap do |json|
        json[:displayName]       = @parameters["display_name"]                    if !@parameters["display_name"].empty?
        json[:email]             = @parameters["email"]                           if !@parameters["email"].empty?
        json[:enabled]           = enabled                                        if !@parameters["enabled"].empty?
        json[:password]          = @parameters["password"]                        if !@parameters["password"].empty?
        json[:spaceAdmin]        = space_admin                                    if !@parameters["space_admin"].empty?
        json[:username]          = URI.encode(@parameters["new_username"])        if !@parameters["new_username"].empty?
        json[:preferredLocale]   = URI.encode(@parameters["preferred_locale"])    if !@parameters["preferred_locale"].empty?
        json[:attributes]        = user["attributes"]                             if !@parameters["attributes"].empty?
        json[:profileAttributes] = user["profileAttributes"]                      if !@parameters["profile_attributes"].empty?
      end

      user_name=@parameters["current_username"]
      # If new_username is supplied set user_name to its value.
      if !@parameters["new_username"].empty?
        user_name=@parameters["new_username"]
      end

      resource.put(data.to_json, { :content_type => "json", :accept => "json" })

      <<-RESULTS
      <results>
        <result name="Username">#{escape(URI.encode(user_name) )}</result>
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
            <result name="Handler Error Message">#{error.http_code}: #{escape(error_message)}</result>
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


  def boolean(string)
    return true if string.downcase == "true" || string =~ (/(true|t|yes|y|1)$/i)
    return false if string.downcase == "false" || string.nil? || string =~ (/(false|f|no|n|0)$/i)
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
