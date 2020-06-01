# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class KineticRequestCeAttachmentUploadV1
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    # Store the info values in a Hash of info names to values.
    @info_values = {}
    REXML::XPath.each(@input_document,"/handler/infos/info") do |item|
      @info_values[item.attributes["name"]] = item.text.to_s.strip
    end

    # Retrieve all of the handler parameters and store them in a hash attribute
    # named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, "/handler/parameters/parameter").each do |item|
      # Associate the attribute name to the String value (stripping leading and
      # trailing whitespace)
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
      user            = @info_values["api_username"]
      pass            = @info_values["api_password"]
      filehub_key     = @info_values["filehub_key"]
      filehub_secret  = @info_values["filehub_secret"]
      kapp_slug       = @parameters["kapp_slug"]
      form_slug       = @parameters["form_slug"]
      filepath        = @parameters['filepath']
      filename        = @parameters["filename"]
      filestore       = @parameters["filestore"]
      expiration      = (DateTime.now.strftime("%Q").to_i + 5000).to_s

      url_for_sig = "#{filehub_secret} GET #{filepath}?expiration=#{expiration}&filename=#{filename}"

      signature = Base64.urlsafe_encode64(Digest::SHA1.digest(url_for_sig))

      pre_signed_url = "#{filestore}#{filepath}?expiration=#{expiration}&filename=#{filename}&key=#{filehub_key}&signature=#{signature}"

      file_content = RestClient.get(pre_signed_url).to_java_bytes

      http_client = DefaultHttpClient.new
      httppost = HttpPost.new("#{server}/#{kapp_slug}/#{form_slug}/files")
      httppost.setHeader("Authorization", "Basic " + Base64.encode64(user + ':' + pass).gsub("\n",''))
      httppost.setHeader("Accept", "application/json")
      reqEntity = MultipartEntity.new
      mime_type = MIME::Types.type_for(@parameters["filename"]).first.content_type
      byte = ByteArrayBody.new(file_content, mime_type, @parameters["filename"])
      reqEntity.addPart("file", byte)
      httppost.setEntity(reqEntity)
      response = http_client.execute(httppost)
      entity = response.getEntity
      resp = EntityUtils.toString(entity)

      # Build the results to be returned by this handler
      puts "RESULT: #{resp}"
      if !resp.nil?
        json = JSON.parse(resp)[0]
        return <<-RESULTS
          <results>
            <result name="Handler Error Message"></result>
            <result name="Content Type">#{escape(json["contentType"])}</result>
            <result name="Document Id">#{escape(json["documentId"])}</result>
            <result name="name">#{escape(json["name"])}</result>
            <result name="size">#{escape(json["size"])}</result>
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
        <result name="Content Type"></result>
        <result name="Document Id"></result>
        <result name="name"></result>
        <result name="size"></result>
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
