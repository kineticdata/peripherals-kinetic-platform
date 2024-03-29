# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), "dependencies"))

class KineticRequestCeSubmissionCloneV1
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
    
    server = @info_values['api_server'].chomp("/")
    if server.include?("${space}")
      server = server.gsub("${space}", space_slug)
    elsif !space_slug.to_s.empty?
      server = "#{server}/#{space_slug}"
    end

    error_handling  = @parameters["error_handling"]
    error_message = nil

    api_username    = URI.encode(@info_values["api_username"])
    api_password    = @info_values["api_password"]

    begin
      # API Route to Get Original Submissions Values
      api_route = "#{server}/app/api/v1/submissions/#{@parameters['submission_id']}?include=values,origin,parent,children,descendents,form,type,form.kapp"
      
      puts "Original API URL: #{api_route}" if @enable_debug_logging
      
      # Build Resource to get orig submission
      resource = RestClient::Resource.new(api_route, { :user => api_username, :password => api_password })
      # Get Orig Submission
      result = resource.get({ :accept => "json", :content_type => "json" })

      # Build Variables for submitting cloned submission
      orig_submission = JSON.parse(result)['submission']
      kapp_slug = orig_submission['form']['kapp']['slug']
      form_slug = orig_submission['form']['slug']
      new_values = @parameters["values"].empty? ? {} : JSON.parse(@parameters["values"])
      orig_values = orig_submission['values']

      # Replace Existing Values with New Values
      new_values.each do |key,value|
        orig_values[key] = value
      end

      # API Route to Create Cloned Submission
      api_route = "#{server}/app/api/v1/kapps/#{kapp_slug}/forms/#{form_slug}/submissions?completed=false"

      puts "API Route for Clone: #{api_route}" if @enable_debug_logging

      # Build Resource to create new submission
      resource = RestClient::Resource.new(api_route, { :user => api_username, :password => api_password })

      # Building the object that will be sent to Kinetic Core
      data = {
        :currentPage => 
          {
            "name" => (@parameters["current_page_name"] if !@parameters["current_page_name"].empty?),
            "navigation" => (@parameters["current_page_navigation"] if !@parameters["current_page_navigation"].empty?)
          },
        :coreState => (@parameters["state"] if !@parameters["state"].empty?),
        :origin => ({"id" => @parameters["origin_id"]} if !@parameters["origin_id"].empty?),
        :parent => ({"id" => @parameters["parent_id"]} if !@parameters["parent_id"].empty?),
        :values => orig_values.empty? ? {} : orig_values
        }

      # Post to the API
      result = resource.post(data.to_json, { :accept => "json", :content_type => "json" })
      new_submission_id = JSON.parse(result)['submission']['id']

      # Patch the Submission Type if a type was provided (This only needs to be done if a type is provided)
      if !@parameters["type"].empty?
        data = {}
        data.tap do |json|
          json[:type] = @parameters["type"] if !@parameters["type"].empty?
        end

        # Build route for patch
        api_route = "#{server}/app/api/v1/submissions/#{new_submission_id}"
        # Build resource for patch
        resource = RestClient::Resource.new(api_route, { :user => api_username, :password => api_password })
        # Patch to the API
        result = resource.patch(data.to_json, { :accept => "json", :content_type => "json" })
      end
    rescue RestClient::Exception => error
      error_message = "#{error.http_code}: #{JSON.parse(error.response)["error"]}"
      raise error_message if error_handling == "Raise Error"
    rescue Exception => error
      error_message = error.inspect
      raise error if error_handling == "Raise Error"
    end

    <<-RESULTS
    <results>
      <result name="Handler Error Message">#{escape(error_message)}</result>
      <result name="Submission ID">#{escape(new_submission_id)}</result>
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
