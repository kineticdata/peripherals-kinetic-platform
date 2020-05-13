# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

# Require the REXML ruby library.
require 'rexml/document'

class KineticRequestCeTeamRetrieveV1
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    # Store the info values in a Hash of info names to values.
    @info_values = {}
    REXML::XPath.each(@input_document,"/handler/infos/info") do |item|
      @info_values[item.attributes['name']] = item.text
    end

    # Retrieve all of the handler parameters and store them in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text.to_s.strip
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
      # Determine what to return based on parameters
      returnParams = ["details"]
      returnParams.push("memberships") if !@parameters["membership"].empty? && @parameters["membership"].downcase == "true"
      returnParams.push("attributes") if !@parameters["attributes"].empty? && @parameters["attributes"].downcase == "true"

      # Build separate variable for what to include to API. We always want membership details
      # so that we can get a count of members
      includes = [].replace(returnParams)
      includes.push("memberships") if !returnParams.include?("memberships")

      # API Route
      route = server + "/app/api/v1/teams?include=#{includes.join(",")}"

      puts "API ROUTE: #{route}" if @enable_debug_logging

      # Build Rest Resource
      resource = RestClient::Resource.new(route,
        user: @info_values['api_username'],password: @info_values['api_password'])

      # Request to the API
      response = resource.get

      # Parse teams from result
      results = JSON.parse(response)["teams"]
      puts "All Teams: #{results.to_json}" if @enable_debug_logging

      # Find Team in Results
      team = results.find { |team| team['name'] == @parameters["team_name"] }

      if team.nil?
        puts "Team not found" if @enable_debug_logging
        return <<-RESULTS
          <results>
             <result name="Name"></result>
             <result name="Description"></result>
             <result name="Slug"></result>
             <result name="Membership JSON"></result>
             <result name="Attributes JSON"></result>
             <result name="Exists">false</result>
             <result name="Has Members">false</result>
             <result name="Handler Error Message"></result>
          </results>
        RESULTS
      else
        puts "Found Team: #{team.to_json}" if @enable_debug_logging

        # Flatten the memberships object so it's not an object within an object
        # For easier processing in the task engine.
        memberships = team['memberships'].map{ |item| item.values }.flatten
        return <<-RESULTS
               <results>
                 <result name="Name">#{escape(team['name'])}</result>
                 <result name="Description">#{escape(team['description'])}</result>
                 <result name="Slug">#{escape(team['slug'])}</result>
                 <result name="Membership JSON">#{escape(memberships.to_json) if returnParams.include?('memberships')}</result>
                 <result name="Attributes JSON">#{escape(team['attributes'].to_json) if returnParams.include?('attributes')}</result>
                 <result name="Exists">true</result>
                 <result name="Has Members">#{memberships.length > 0}</result>
                 <result name="Handler Error Message"></result>
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