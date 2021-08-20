# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class KineticRequestCeAttachmentCreateV2
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

    begin
      error_handling  = @parameters["error_handling"]
      error_message = nil

      filename = @parameters["filename"]
      # To support Base64 as an input it must be decoded.  
      file_content =  @parameters["input_encoding"] == "Base64" ?
        Base64.decode64(@parameters["file_content"]) :
        @parameters["file_content"] 

      http_client = DefaultHttpClient.new
      httppost = HttpPost.new("#{server}/#{@parameters["kapp_slug"]}/#{@parameters["form_slug"]}/files")
      httppost.setHeader("Authorization", "Basic " + Base64.encode64(@info_values["api_username"] + ':' + @info_values["api_password"]).gsub("\n",''))
      httppost.setHeader("Accept", "application/json")
      reqEntity = MultipartEntity.new
      byte = ByteArrayBody.new(file_content.to_java_bytes, "text/plain", @parameters["filename"])
      reqEntity.addPart("file", byte)
      httppost.setEntity(reqEntity)
      response = http_client.execute(httppost)
      entity = response.getEntity
      resp = EntityUtils.toString(entity)

      if response.getStatusLine.getStatusCode != 200
        error_message = "#{response.getStatusLine.getStatusCode}: #{JSON.parse(resp)["error"]}"
        raise error_message if error_handling == "Raise Error"
      end
    rescue Exception => error
      error_message = error.inspect
      raise error if error_handling == "Raise Error"
    end

    return <<-RESULTS
    <results>
      <result name="Files">#{error_message.nil? ? escape(resp) : ""}</result>
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
