# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), "dependencies"))

class KineticRequestCeDatastoreSubmissionRetrieveV1
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

    if @parameters['retrieve_by'] == "Query"
      if @parameters['form_slug'].to_s.empty? || @parameters['index'].to_s.empty? ||
         @parameters['query'].to_s.empty?
        raise "'Form Slug','Index', and 'Query' are all required fields when attempting to retrieve by query"
      end
    else
      if @parameters['submission_id'].to_s.empty?
        raise "'Submission Id' is a required field when attempting to retrieve by id"
      end
    end
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
      api_username    = URI.encode(@info_values["api_username"])
      api_password    = @info_values["api_password"]

      api_route = "#{server}/app/api/v1/datastore"
      includes = "details,form,values"
      if @parameters['retrieve_by'] == "Id"
        api_route += "/submissions/#{@parameters["submission_id"]}?include=#{includes}"
      elsif @parameters['retrieve_by'] == "Query"
        api_route += "/forms/#{@parameters['form_slug']}/submissions"
        api_route += "?include=#{includes}&index=#{URI.encode(@parameters['index'])}&q=#{CGI.escape(@parameters['query'])}&limit=1"
      else
        raise "Retrieve By type '#{@parameters['retrieve_by']}' not supported"
      end

      puts "API ROUTE: #{api_route}" if @enable_debug_logging
      resource = RestClient::Resource.new(api_route, { :user => api_username, :password => api_password })
      response = JSON.parse(resource.get)

      results = @parameters["retrieve_by"] == "Id" ? response["submission"] : response["submissions"][0]

      # Build the results to be returned by this handler
      if response.nil? || results.nil?
        return <<-RESULTS
        <results>
          <result name="Handler Error Message"/>
          <result name="ID"/>
          <result name="Label"/>
          <result name="Handle"/>
          <result name="Core State"/>
          <result name="Current Page"/>
          <result name="Submitted At"/>
          <result name="Submitted By"/>
          <result name="Updated At"/>
          <result name="Updated By"/>
          <result name="Created At"/>
          <result name="Created By"/>
          <result name="Form Description"/>
          <result name="Form Name"/>
          <result name="Form Notes"/>
          <result name="Form Slug"/>
          <result name="Form Status"/>
          <result name="Values JSON"/>
        </results>
        RESULTS
      else
        puts "RESULTS: #{results.inspect}" if @enable_debug_logging
        return <<-RESULTS
        <results>
          <result name="Handler Error Message"></result>
          <result name="ID">#{escape(results['id'])}</result>
          <result name="Label">#{escape(results['label'])}</result>
          <result name="Handle">#{escape(results['handle'])}</result>
          <result name="Core State">#{escape(results['coreState'])}</result>
          <result name="Current Page">#{escape(results['currentPage'])}</result>
          <result name="Submitted At">#{escape(results['submittedAt'])}</result>
          <result name="Submitted By">#{escape(results['submittedBy'])}</result>
          <result name="Updated At">#{escape(results['updatedAt'])}</result>
          <result name="Updated By">#{escape(results['updatedBy'])}</result>
          <result name="Created At">#{escape(results['createdAt'])}</result>
          <result name="Created By">#{escape(results['createdBy'])}</result>
          <result name="Form Description">#{escape(results['form']['description'])}</result>
          <result name="Form Name">#{escape(results['form']['name'])}</result>
          <result name="Form Notes">#{escape(results['form']['notes'])}</result>
          <result name="Form Slug">#{escape(results['form']['slug'])}</result>
          <result name="Form Status">#{escape(results['form']['status'])}</result>
          <result name="Values JSON">#{escape(results['values'].to_json)}</result>
        </results>
        RESULTS
      end
    rescue RestClient::Exception => error
      error_message = "#{error.http_code}: #{JSON.parse(error.response)["error"]}"
      raise error_message if error_handling == "Raise Error"
    rescue Exception => error
      error_message = error.inspect
      raise error if error_handling == "Raise Error"
    end

    # Return the error message if it was caught. Actual results are being returned above if there
    # wasn't a caught error
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
