# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), "dependencies"))

class KineticRequestCeSubmissionRetrieveV1
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
    submission_id   = @parameters["submission_id"]
    error_handling  = @parameters["error_handling"]

    api_route = "#{server}/app/api/v1/submissions/#{submission_id}/?include=details,origin,parent,children,descendents,form,type,form.kapp"

    puts "API ROUTE: #{api_route}" if @enable_debug_logging

    resource = RestClient::Resource.new(api_route, { :user => api_username, :password => api_password })

    response = resource.get

    # Build the results to be returned by this handler
    if response.nil?
      <<-RESULTS
      <results>
      <result name="Handler Error Message"></result>
        <result name="ID"></result>
        <result name="Label"></result>
        <result name="Handle"></result>
        <result name="Origin"></result>
        <result name="Parent"></result>
        <result name="Submitted At"></result>
        <result name="Type"></result>
        <result name="Updated At"></result>
        <result name="Updated By"></result>
        <result name="Closed At"></result>
        <result name="Core State"></result>
        <result name="Created At"></result>
        <result name="Created By"></result>
        <result name="Form Description"></result>
        <result name="Form Name"></result>
        <result name="Form Notes"></result>
        <result name="Form Slug"></result>
        <result name="Form Status"></result>
        <result name="Kapp Name"></result>
        <result name="Kapp Slug"></result>
      </results>
      RESULTS
    else
      results = JSON.parse(response)["submission"]
      puts "RESULTS: #{results.inspect}" if @enable_debug_logging
      <<-RESULTS
      <results>
        <result name="Handler Error Message"></result>
        <result name="ID">#{escape(results['id'])}</result>
        <result name="Label">#{escape(results['label'])}</result>
        <result name="Handle">#{escape(results['handle'].to_json)}</result>
        <result name="Origin">#{escape(results['origin'].to_json)}</result>
        <result name="Parent">#{escape(results['parent'].to_json)}</result>
        <result name="Submitted At">#{escape(results['submittedAt'])}</result>
        <result name="Type">#{escape(results['type'])}</result>
        <result name="Updated At">#{escape(results['updatedAt'])}</result>
        <result name="Updated By">#{escape(results['updatedBy'])}</result>
        <result name="Closed At">#{escape(results['closedAt'])}</result>
        <result name="Core State">#{escape(results['coreState'])}</result>
        <result name="Created At">#{escape(results['createdAt'])}</result>
        <result name="Created By">#{escape(results['createdBy'])}</result>
        <result name="Form Description">#{escape(results['form']['description'])}</result>
        <result name="Form Name">#{escape(results['form']['name'])}</result>
        <result name="Form Notes">#{escape(results['form']['notes'])}</result>
        <result name="Form Slug">#{escape(results['form']['slug'])}</result>
        <result name="Form Status">#{escape(results['form']['status'])}</result>
        <result name="Kapp Name">#{escape(results['form']['kapp']['name'])}</result>
        <result name="Kapp Slug">#{escape(results['form']['kapp']['slug'])}</result>
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
