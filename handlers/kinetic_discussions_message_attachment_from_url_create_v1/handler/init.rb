# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), "dependencies"))
require 'uri'

class KineticDiscussionsMessageAttachmentFromUrlCreateV1
  # ==== Parameters
  # * +input+ - The String of Xml that was built by evaluating the node.xml handler template.
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

    @debug_logging_enabled = ["yes","true"].include?(@info_values['enable_debug_logging'].downcase)
    @error_handling = @parameters["error_handling"]

    @api_oauth_location = @info_values["api_oauth_location"]
    @api_location = @info_values["api_location"]
    @api_location.chomp!("/")
    @api_username = @info_values["api_username"]
    @api_password = @info_values["api_password"]


    @path = @parameters["path"]
    @path = "/#{@path}" if !@path.start_with?("/")

    @filename = @parameters["filename"]
    @download_url = @parameters["url"]
  end

  def execute
    # Initialize return data
    error_message = nil
    error_key = nil
    response_code = nil
    oauth_error_message = nil
    oauth_error_key = nil
    oauth_response_code = nil

    # Discussions only authenticates with a bearer token, so get a token
    # that works for the provided credentials from the oauth location
    begin
      puts "Retrieving oauth token: POST #{@api_oauth_location}" if @debug_logging_enabled
      oauth_response = RestClient::Request.execute \
        method: :post,
        url: @api_oauth_location,
        user: @api_username,
        password: @api_password,
        headers: {
          :accept => :json,
          :content_type => :json
        }
      oauth_response_code = oauth_response.code
      bearer_token = JSON.parse(oauth_response)["access_token"]
      puts "Retrieved oauth token: #{bearer_token}" if @debug_logging_enabled
    rescue => e
      puts "oauth error: #{e.inspect}" if @debug_logging_enabled
      if @error_handling
        begin
          # Attempt to parse the JSON error message. Re-throw the original error if the
          # parsing fails
          response_json = JSON.parse(e.response)
          oauth_error_message = response_json["error"]
          oauth_error_key = response_json["errorKey"]
          oauth_response_code = e.response.code
        rescue Exception
          puts "There was an error parsing the JSON error response" if @debug_logging_enabled
          oauth_error_message = e.inspect
        end
      else
        raise
      end

      # Return (and escape) the results that were defined in the node.xml
      return <<-RESULTS
      <results>
        <result name="Response Body">{}</result>
        <result name="Response Code"></result>
        <result name="Handler Error Key"></result>
        <result name="Handler Error Message"></result>
        <result name="OAuth Response Code">#{escape(oauth_response_code)}</result>
        <result name="OAuth Error Key">#{escape(oauth_error_key)}</result>
        <result name="OAuth Error Message">#{escape(oauth_error_message)}</result>
      </results>
      RESULTS
    end

    begin
      # Download the attachment
      puts "Retrieving attachment: #{@download_url}" if @debug_logging_enabled
      file_dl_response = RestClient.get(@download_url)
      file_content_type = file_dl_response.headers[:content_type]
      puts "Attachment content type: #{file_content_type}" if @debug_logging_enabled

      # Upload the attachment to discussions
      http_client = DefaultHttpClient.new
      httppost = HttpPost.new("#{@api_location}#{@path}")
      httppost.setHeader("Authorization", "Bearer #{bearer_token}")
      httppost.setHeader("Accept", "application/json")
      reqEntity = MultipartEntity.new

      message = {"content" => []}
      string_body = org.apache.http.entity.mime.content.StringBody.new(message.to_json)
      reqEntity.addPart("message", string_body)

      file_bytes = ByteArrayBody.new(file_dl_response.body.to_java_bytes,file_content_type, @filename)
      reqEntity.addPart("attachments", file_bytes)
      httppost.setEntity(reqEntity)

      puts "Uploading attachment to a discussion message: #{httppost.getURI}" if @debug_logging_enabled
      response = http_client.execute(httppost)

      entity = response.getEntity
      utf8 =
      resp = EntityUtils.toString(entity)

      if response.getStatusLine.getStatusCode == 200
        puts "Discussion attachment response: #{response.getStatusLine.getStatusCode}" if @debug_logging_enabled
      else
        error_message = "#{response.getStatusLine.getStatusCode}: #{JSON.parse(resp)["error"]}"
        puts "Discussion attachment response: #{error_message}" if @debug_logging_enabled
        raise error_message if @error_handling == "Raise Error"
      end
    rescue Exception => error
      puts "ERROR: #{error.inspect}"
      error_message = error.inspect
      raise error if @error_handling == "Raise Error"
    end

    # Return (and escape) the results that were defined in the node.xml
    <<-RESULTS
    <results>
      <result name="Response Body">{}</result>
      <result name="Response Code">#{escape(response_code)}</result>
      <result name="Handler Error Key">#{escape(error_key)}</result>
      <result name="Handler Error Message">#{escape(error_message)}</result>
      <result name="OAuth Response Code">#{escape(oauth_response_code)}</result>
      <result name="OAuth Error Key">#{escape(oauth_error_key)}</result>
      <result name="OAuth Error Message">#{escape(oauth_error_message)}</result>
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
