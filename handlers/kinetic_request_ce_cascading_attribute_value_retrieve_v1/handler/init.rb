# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), "dependencies"))

class KineticRequestCeCascadingAttributeValueRetrieveV1
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
    begin
      space_slug      = @parameters["space_slug"].empty? ? @info_values["space_slug"] : @parameters["space_slug"]
      if @info_values['api_server'].include?("${space}")
        server = @info_values['api_server'].gsub("${space}", space_slug)
      elsif !space_slug.to_s.empty?
        server = @info_values['api_server']+"/"+space_slug
      else
        server = @info_values['api_server']
      end

      api_username    = URI.encode(@info_values["api_username"])
      api_password    = @info_values["api_password"]
      start_context   = @parameters["start_context"]
      end_context     = @parameters["end_context"]
      prop_to_find    = @parameters["prop_to_find"]
      backup          = @parameters["backup_if_none"]
      error_handling  = @parameters["error_handling"]
      kapp_slug       = @parameters["kapp_slug"].empty? ? nil : @parameters["kapp_slug"]
      form_slug       = @parameters["form_slug"].empty? ? nil : @parameters["form_slug"]
      submission_id   = @parameters["submission_id"].empty? ? nil : @parameters["submission_id"]
      error_message   = nil
      api_route       = "#{server}/app/api/v1/"
      valid_route     = false

      ######################################################
      ### BEGIN Ensure required parameters were provided ###
      ######################################################

      # Check for Submission Start Context
      if start_context == "Submission"
        if submission_id.nil?
          error_message = "Intending to search submissions context but no submission id provided"
        else
          api_route = api_route + "submissions/#{submission_id}?include=values,form.attributes,form.kapp.attributes,form.kapp.space.attributes"
          valid_route = true
        end
      end
      # Check for Form Start Context
      if start_context == "Form"
        if form_slug.nil?  || kapp_slug.nil?
          error_message = "Intending to search kapp context but no kapp slug provided"
        else
          api_route = api_route + "kapps/#{kapp_slug}/forms/#{form_slug}?include=attributes,kapp.attributes,kapp.space.attributes"
          valid_route = true
        end
      end
      # Check for Kapp Start Context
      if start_context == "Kapp"
        if kapp_slug.nil?
          error_message = "Intending to search kapp context but no kapp slug provided"
        else
          api_route = api_route + "kapps/#{kapp_slug}?include=attributes,space.attributes"
          valid_route = true
        end
      end
      # Check for Space Start Context
      if start_context == "Space"
        if space_slug.empty?
        error_message = "Intending to search space context but no space slug provided"
        else
          api_route = api_route + "space?include=attributes"
          valid_route = true
        end
      end

      ######################################################
      ### END Ensure required parameters were provided ###
      ######################################################

      # If required parameters exist & valid route was built, begin
      if valid_route
        resource = RestClient::Resource.new(api_route, { :user => api_username, :password => api_password })
        response = resource.get

        # Build the results to be returned by this handler
        if response.nil?
          puts "NIL RESPONSE"
          <<-RESULTS
          <results>
            <result name="Handler Error Message"/>
            <result name="Matched Context">Backup</result>
            <result name="Value">#{escape(backup)}</result>
          </results>
          RESULTS
        else
          # Parse the Results returned from the API
          results         = JSON.parse(response)
          # Set a variable to keep track matches
          value           = nil
          matched_context = nil
          matchFound      = false
          types           = []

          if start_context == "Submission"
            types = buildForSubmissionRoute(results, end_context)
          end

          if start_context == "Form"
            types = buildForFormRoute(results, end_context)
          end

          if start_context == "Kapp"
            types = buildForKappRoute(results, end_context)
          end

          if start_context == "Space"
            types = buildForSpaceRoute(results, end_context)
          end

          # Loop over object type (Attributes / Submission Values) that was returned
          types.each do |type|
            # If no match was found yet, keep trying
            if !matchFound
              # Search through the names of attributes/fields returned and try to match with the prop_to_find parameter
              # Make sure that the value isn't blank as well
              matchingHash = type['Data'].find {|hash| hash['name'] == prop_to_find && hash['values'].length > 0 }
              # If a match was found see if a valid value exists othwise keep searching
              if !matchingHash.nil?
                # Search each value (Checkbox Questions / Attributes can have multiple values)
                matchingHash['values'].each do |attrValue|
                  # If previous values were nil, keep trying
                  if value.nil?
                    if !attrValue.to_s.empty?
                      value = attrValue
                      matched_context = type['Type']
                      matchFound = true
                    end
                  end
                end
              end
            end
          end

          # Use Backup if no value was found
          if value.nil?
            value = backup
            matched_context = "Backup"
          end

          puts "Value: #{value}"
          puts "Matched Context: #{matched_context}"

          # Return Results
          <<-RESULTS
          <results>
            <result name="Handler Error Message"></result>
            <result name="Matched Context">#{escape(matched_context)}</result>
            <result name="Value">#{escape(value)}</result>
          </results>
          RESULTS
        end
      else
        puts "Error Finding Value"
        # Return Error Results
        <<-RESULTS
        <results>
          <result name="Handler Error Message">#{escape(error_message)}</result>
          <result name="Matched Context">Backup</result>
          <result name="Value">#{escape(backup)}</result>
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
  end

  ##############################################################################
  # General handler utility functions
  ##############################################################################

  def buildForSubmissionRoute(data, end_context)
    attributes = []
    attributes.push({"Type" => "Submission Value", "Data" => data['submission']['values'].map{|k,v| {"name"=>k,"values"=>Array(v)}}})
    if end_context == "Space"
      attributes.push({"Type" => "Form Attribute", "Data" => data['submission']['form']['attributes']})
      attributes.push({"Type" => "Kapp Attribute", "Data" => data['submission']['form']['kapp']['attributes']})
      attributes.push({"Type" => "Space Attribute", "Data" => data['submission']['form']['kapp']['space']['attributes']})
    elsif end_context == "Kapp"
      attributes.push({"Type" => "Form Attribute", "Data" => data['submission']['form']['attributes']})
      attributes.push({"Type" => "Kapp Attribute", "Data" => data['submission']['form']['kapp']['attributes']})
    elsif end_context == "Form"
      attributes.push({"Type" => "Form Attribute", "Data" => data['submission']['form']['attributes']})
    end
    # Return Attributes
    return attributes
  end

  def buildForFormRoute(data, end_context)
    attributes = []
    attributes.push({"Type" => "Form Attribute", "Data" => data['form']['attributes']})
    if end_context == "Space"
      attributes.push({"Type" => "Kapp Attribute", "Data" => data['form']['kapp']['attributes']})
      attributes.push({"Type" => "Space Attribute", "Data" => data['form']['kapp']['space']['attributes']})
    elsif end_context == "Kapp"
      attributes.push({"Type" => "Kapp Attribute", "Data" => data['form']['kapp']['attributes']})
    end

    # Return Attributes
    return attributes
  end

  def buildForKappRoute(data, end_context)
    attributes = []
    attributes.push({"Type" => "Kapp Attribute", "Data" => data['kapp']['attributes']})
    if end_context == "Space"
      attributes.push({"Type" => "Space Attribute", "Data" => data['kapp']['space']['attributes']})
    end

    # Return Attributes
    return attributes
  end

  def buildForSpaceRoute(data, end_context)
    attributes = []
    attributes.push({"Type" => "Space Attribute", "Data" => data['space']['attributes']})

    # Return Attributes
    return attributes
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
