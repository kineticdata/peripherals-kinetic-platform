# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), "dependencies"))

class KineticRequestCeAttributeValuesRetrieveV1
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
    space_slug = @parameters["space_slug"].empty? ? @info_values["space_slug"] : @parameters["space_slug"]
    if @info_values['api_server'].include?("${space}")
      server = @info_values['api_server'].gsub("${space}", space_slug)
    elsif !space_slug.to_s.empty?
      server = @info_values['api_server']+"/"+space_slug
    else
      server = @info_values['api_server']
    end

    begin
      api_username    = URI.encode(@info_values["api_username"])
      api_password    = @info_values["api_password"]
      error_handling  = @parameters["error_handling"]
      kapp_slug       = @parameters["kapp_slug"].to_s.strip.empty? ? nil : @parameters["kapp_slug"].to_s.strip
      form_slug       = @parameters["form_slug"].to_s.strip.empty? ? nil : @parameters["form_slug"].to_s.strip
      error_message   = nil
      api_route       = "#{server}/app/api/v1"


      # Build the route for the appropriate attributes
      if space_slug.nil?
        error_message = "A space slug must be provided."
      elsif !form_slug.nil? && kapp_slug.nil?
        error_message = "A kapp slug must be provided if a form slug is provided."
      elsif !form_slug.nil? && !kapp_slug.nil?
        api_route = "#{api_route}/kapps/#{kapp_slug}/forms/#{form_slug}?include=attributes,kapp.attributes,kapp.space.attributes"
      elsif !kapp_slug.nil?
        api_route = "#{api_route}/kapps/#{kapp_slug}?include=attributes,space.attributes"
      else
        api_route = "#{api_route}/space?include=attributes"
      end


      if error_message.nil?
        resource = RestClient::Resource.new(api_route, { :user => api_username, :password => api_password })
        response = resource.get

        # Build the results to be returned by this handler
        if response.nil?
          <<-RESULTS
          <results>
            <result name="Handler Error Message">NULL RESPONSE</result>
            <result name="Space Attributes"/>
            <result name="Kapp Attributes"/>
            <result name="Form Attributes"/>
          </results>
          RESULTS
        else
          # Parse the Results returned from the API
          results         = JSON.parse(response)

          space_attributes = []
          kapp_attributes = []
          form_attributes = []

          if results.has_key?('form')
            space_attributes = results['form']['kapp']['space']['attributes']
            kapp_attributes = results['form']['kapp']['attributes']
            form_attributes = results['form']['attributes']
          elsif results.has_key?('kapp')
            space_attributes = results['kapp']['space']['attributes']
            kapp_attributes = results['kapp']['attributes']
          else
            space_attributes = results['space']['attributes']
          end

          results = <<-RESULTS
          <results>
            <result name="Handler Error Message"/>
            <result name="Space Attributes">#{map_attributes(space_attributes).to_json}</result>
            <result name="Kapp Attributes">#{map_attributes(kapp_attributes).to_json}</result>
            <result name="Form Attributes">#{map_attributes(form_attributes).to_json}</result>
          </results>
          RESULTS
          puts results
          results
        end
      else
        # Return Error Results
        <<-RESULTS
        <results>
          <result name="Handler Error Message">#{escape(error_message)}</result>
          <result name="Space Attributes"/>
          <result name="Kapp Attributes"/>
          <result name="Form Attributes"/>
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
          <result name="Space Attributes"/>
          <result name="Kapp Attributes"/>
          <result name="Form Attributes"/>
        </results>
        RESULTS
      end
    end
  end

  ##############################################################################
  # General handler utility functions
  ##############################################################################

  def map_attributes(attributes)
    attributes.map { |attribute| { attribute['name'] => attribute['values'] } }
  end


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
