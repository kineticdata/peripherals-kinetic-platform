# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

require 'digest'
# Require the REXML ruby library.
require 'rexml/document'

class KineticRequestCeAttributesSetV1
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
      raise "A Kapp Slug is required when attempting to create a definition for the following types: "+
        "Kapp, Category, Form" if @parameters['kapp_slug'].to_s.empty? && ["Kapp","Category","Form"].include?(@parameters['type'])

      # Build the API route depending on what type was passed as a parameter
      puts "Building the API route based on the inputted type" if @enable_debug_logging
      api_route = "#{server}/app/api/v1/"
      type_routes = {
        "Space"        => "space",
        "Team"         => "teams",
        "User"         => "users",
        "User Profile" => "users",
        "Kapp"         => "kapps",
        "Category"     => "kapps/#{@parameters['kapp_slug']}/categories",
        "Form"         => "kapps/#{@parameters['kapp_slug']}/forms"
      }
      api_route += type_routes[@parameters['type']]
      puts "Base API route: #{api_route}" if @enable_debug_logging

      resource = RestClient::Resource.new(api_route,
        user: @info_values["api_username"], password: @info_values["api_password"],
        accept: :json, content_type: :json)

      if @parameters["type"] == "Kapp" && !@parameters["kapp_slug"].to_s.empty?
        @parameters["type_id"] = @parameters["kapp_slug"]
      elsif @parameters["type"] == "Team"
        md5 = Digest::MD5.new
        md5.update @parameters["type_id"]
        @parameters["type_id"] = md5.hexdigest
      end
      update_all = @parameters['type_id'].to_s.empty?

      if @parameters["type"] == "Space"
        @parameters["type_id"] = ""
        update_all = false
      end

      type_path = ""
      type_path = "#{URI.encode(@parameters['type_id'])}" if !update_all
      type_path += "?include=attributes,profileAttributes"

      puts "Getting the #{@parameters['type']} object to see the current attribute states" if @enable_debug_logging

      response = JSON.parse(resource[type_path].get)

      objects = response[response.keys.first]
      # Change the single object into an array if we are only updating one
      objects = [objects] if !update_all
      # Parse Attributes passed as inputs
      new_attributes = JSON.parse(@parameters["attributes"])

      objects.each do |object|
        type_id_key = @parameters['type'].include?("User") ? "username" : "slug"
        obj_id = object[type_id_key]
        obj_attributes = @parameters["type"] == "User Profile" ? object["profileAttributes"] : object["attributes"]
        change_flag = false

        new_attributes.each do |attribute|
          # Determine if the attribute already exists on the object (returns attribute name if it does)
          exists = obj_attributes.find_index {|item| item['name'] == attribute['name']}

          if exists.nil?
            # If attribute doesn't exist and we need to create a new one, create the attribute
            if @parameters["create_new"].downcase == "true"
              obj_attributes.push(attribute)
              change_flag = true
            else
              # If the attribute doesn't exist and we shouldn't create a new one, go to the next attributes
              next
            end
          # If the attribute DOES exist, and is not the same as the attribute provided in the parameter update it
          elsif obj_attributes[exists] != attribute
            obj_attributes[exists] = attribute
            change_flag = true
          # If the attribute DOES exist, but it is the same, go to the next attribute
          else
            next
          end
        end

        # If a change was made, update the form
        if change_flag
          puts "Updating #{@parameters['type']} '#{@parameters['type'] == "Team" ? object["name"] : obj_id}' "+
            "with new attributes" if @enable_debug_logging
          # Build request to be sent for each form that needs to be updated
          data = {}
          data.tap do |json|
            if @parameters["type"] == "User Profile"
              json[:profileAttributes] = obj_attributes if !obj_attributes.nil?
            else
              json[:attributes] = obj_attributes if !obj_attributes.nil?
            end
          end

          if @parameters['type'] == "Space"
            resource.put(data.to_json)
          else
            resource[URI.escape(obj_id)].put(data.to_json)
          end
        end
      end
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
