# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), "dependencies"))

class KineticRequestCeSubmissionCreateV1
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

    error_handling  = @parameters["error_handling"]
    error_message = nil

    api_username    = URI.encode(@info_values["api_username"])
    api_password    = @info_values["api_password"]
    kapp_slug       = @parameters["kapp_slug"]
    form_slug       = @parameters["form_slug"]

    begin
      api_route = "#{server}/app/api/v1/kapps/#{kapp_slug}/forms/#{form_slug}/submissions"

      puts "API ROUTE: #{api_route}" if @enable_debug_logging

      resource = RestClient::Resource.new(api_route, { :user => api_username, :password => api_password })

      # Building the object that will be sent to Kinetic Core
      data = {}
      data.tap do |json|
        json[:currentPage] = {
                               "name" => (@parameters['current_page_name'] if !@parameters['current_page_name'].empty?),
                               "navigation" => (@parameters['current_page_navigation'] if !@parameters['current_page_navigation'].empty?)
                             }

        json[:origin] = {"id" => @parameters['origin_id']} if !@parameters['origin_id'].empty?
        json[:parent] = {"id" => @parameters['parent_id']} if !@parameters['parent_id'].empty?
        json[:values] = @parameters['values'].empty? ? {} : JSON.parse(@parameters['values'])
      end

      puts "DATA: #{data.to_json}" if @enable_debug_logging

      # Post to the API
      response = resource.post(data.to_json, { :accept => "json", :content_type => "json" })

      submission = JSON.parse(response)
      puts "SUBMISSION: #{submission.inspect}"
      submission_id = submission['submission']['id']
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
      <result name="Submission ID">#{escape(submission_id)}</result>
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
