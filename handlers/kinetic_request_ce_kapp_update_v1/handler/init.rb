# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

# Require the REXML ruby library.
require 'rexml/document'

class KineticRequestCeKappUpdateV1
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    # Store the info values in a Hash of info names to values.
    @info_values = {}
    REXML::XPath.each(@input_document,"/handler/infos/info") do |item|
      @info_values[item.attributes["name"]] = item.text.to_s.strip
    end

    # Retrieve all of the handler parameters and store them in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, "/handler/parameters/parameter").each do |item|
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

    error_handling  = @parameters["error_handling"]
    error_message = nil

    begin
      # API Route
      api_route = server + "/app/api/v1/kapps/" +
                  @parameters["orig_kapp_slug"] + "?include=attributes"

      puts "API ROUTE: #{api_route}" if @enable_debug_logging

      resource = RestClient::Resource.new(api_route,
                                          user: @info_values["api_username"],
                                          password: @info_values["api_password"])

      # Test to see if we're updating attributes
      # If we are, get the current attributes from the space
      # Loop over the new attributes and update the current attributes (which will be passed in the PUT)
      current_attributes = nil
      if !@parameters["attributes"].empty?
        # Get the spaces current attributes
        response = resource.get({ accept: :json, content_type: :json })
        current_attributes = JSON.parse(response)['kapp']['attributes']

        # Parse the new attributes and loop over them to see if they already exist
        new_attributes = JSON.parse(@parameters["attributes"])
        new_attributes.each do |attribute|
          # If the attribute exists, replace it
          exists = current_attributes.find_index {|item| item['name'] == attribute['name']}
          exists.nil? ? current_attributes.push(attribute) : current_attributes[exists] = attribute
        end
      end

      # Building the object that will be sent to Kinetic Core
      data = {}
      data.tap do |json|
        json[:slug] = @parameters["new_kapp_slug"] if !@parameters["new_kapp_slug"].empty?
        json[:name] = @parameters["new_kapp_name"] if !@parameters["new_kapp_name"].empty?
        json[:bundlePath] = @parameters["bundle_path"] if !@parameters["bundle_path"].empty?
        json[:attributes] = current_attributes if !current_attributes.nil?
      end

      puts "DATA: #{data.to_json}" if @enable_debug_logging

      # Post to the API
      result = resource.put(data.to_json, { accept: :json, content_type: :json })
    rescue RestClient::Exception => error
      error_message = "#{error.http_code}: #{JSON.parse(error.response)["error"]}"
      raise error_message if error_handling == "Raise Error"
    rescue Exception => error
      error_message = error.inspect
      raise error if error_handling == "Raise Error"
    end

    # Build the results to be returned by this handler
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
