# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

# Require the REXML ruby library.
require 'rexml/document'
# Require other libraries
require 'uri'

class KineticBridgehubBridgeCreateV1
  # Prepare for execution by building Hash objects for necessary values, and
  # validating the present state.  This method sets the following instance
  # variables:
  # * @input_document - A REXML::Document object that represents the input Xml.
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

    # Store the info values in a Hash of info names to values.
    @info_values = {}
    REXML::XPath.each(@input_document,"/handler/infos/info") do |item|
      @info_values[item.attributes["name"]] = item.text.to_s.strip
    end

    # Retrieve all of the handler parameters and store them in a hash attribute
    # named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, "/handler/parameters/parameter").each do |item|
      # Associate the attribute name to the String value (stripping leading and
      # trailing whitespace)
      @parameters[item.attributes["name"]] = item.text.to_s.strip
    end
  end

  # Create a bridge in Bridgehub
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Returns
  # An Xml formatted String representing the return variable results.
  def execute
    begin
      bridgehub_url = @info_values["api_server"] + "/app/manage-api/v1/bridges"
      resource = RestClient::Resource.new(bridgehub_url,
                          user: @info_values["api_username"],
                          password: @info_values["api_password"])

      # Create the bridge data
      data = {}
      data.tap do |json|
        json['adapterClass'] = @parameters["adapter_class"]
        json['name'] = @parameters["name"]
        json['slug'] = @parameters["slug"]
        json['ipAddresses'] = @parameters["ip_addresses"]
        json['properties'] = @parameters["properties"].empty? ? {} : JSON.parse(@parameters["properties"])
      end

      # POST to the API
      response = resource.post(data.to_json, { accept: :json, content_type: :json })

      # build and return the results
      bridge = JSON.parse(response)["bridge"]
      return <<-RESULTS
      <results>
        <result name="adapterClass">#{escape(bridge["adapterClass"])}</result>
        <result name="ipAddresses">#{escape(bridge["ipAddresses"])}</result>
        <result name="name">#{escape(bridge["name"])}</result>
        <result name="slug">#{escape(bridge["slug"])}</result>
        <result name="properties">#{escape(bridge["properties"].to_json)}</result>
      </results>
      RESULTS

    # If the credentials are invalid
    rescue RestClient::Unauthorized
      raise StandardError, "(Unauthorized): You are not authorized."
    rescue RestClient::BadRequest => error
      raise StandardError, error.response
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

  # This is a sample helper method that illustrates one method for retrieving
  # values from the input document.  As long as your node.xml document follows
  # a consistent format, these type of methods can be copied and reused between
  # handlers.
  def get_info_value(document, name)
    # Retrieve the XML node representing the desired info value
    info_element = REXML::XPath.first(document, "/handler/infos/info[@name='#{name}']")
    # If the desired element is nil, return nil; otherwise return the text value of the element
    info_element.nil? ? nil : info_element.text
  end
end
