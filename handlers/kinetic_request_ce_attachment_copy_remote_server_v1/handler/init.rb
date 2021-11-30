require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class KineticRequestCeAttachmentCopyRemoteServerV1
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    # Store the info values in a Hash of info names to values.
    @info_values = {}
    REXML::XPath.each(@input_document,"/handler/infos/info") do |item|
      @info_values[item.attributes['name']] = item.text
    end

    # Retrieve all of the handler parameters and store them in a hash attribute
    # named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, 'handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text.to_s
    end

    @enable_debug_logging = @info_values['enable_debug_logging'].downcase == 'yes' ||
                            @info_values['enable_debug_logging'].downcase == 'true'
    puts "Parameters: #{@parameters.inspect}" if @enable_debug_logging

    # determine this file's current directory
    pwd = File.dirname(File.expand_path(__FILE__))

    # create the temp file directory if it doesn't exist
    @tmp_dir = File.join(pwd, 'tmp_filecopy_zips')
    FileUtils.mkdir_p @tmp_dir
  end

  def execute()
    source_space_slug = @parameters["source_space_slug"].empty? ? @info_values["source_space_slug"] : @parameters["source_space_slug"]
    if @info_values['source_api_server'].include?("${space}")
      source_server = @info_values['source_api_server'].gsub("${space}", source_space_slug)
    elsif !source_space_slug.to_s.empty?
      source_server = @info_values['source_api_server']+"/"+source_space_slug
    else
      source_server = @info_values['source_api_server']
    end

    
    destination_space_slug = @parameters["source_space_slug"].empty? ? @info_values["destination_space_slug"] : @parameters["destination_space_slug"]
    if @info_values['destination_api_server'].include?("${space}")
      destination_server = @info_values['destination_api_server'].gsub("${space}", destination_space_slug)
    elsif !destination_space_slug.to_s.empty?
      destination_server = @info_values['destination_api_server']+"/"+destination_space_slug
    else
      destination_server = @info_values['destination_api_server']
    end
   
    #Source Variables
    source_user            = @info_values["source_api_username"]
    source_pass            = @info_values["source_api_password"]
    source_kapp_slug       = @parameters["source_kapp_slug"]
    source_form_slug       = @parameters["source_form_slug"]
    source_submission_id   = @parameters["source_submission_id"]
    source_field_name      = @parameters["source_field_name"]
    #Destination Variables
    destination_user            = @info_values["destination_api_username"]
    destination_pass            = @info_values["destination_api_password"]
    destination_kapp_slug       = @parameters["destination_kapp_slug"]
    destination_form_slug       = @parameters["destination_form_slug"]
    destination_submission_id   = @parameters["destination_submission_id"]    
    destination_field_name      = @parameters["destination_field_name"]
    #Other Variables
    error_handling  = @parameters["error_handling"]    
    imported_files = []
    imported_file_details = []

     # Submission API Route including Values
      submission_api_route = source_server +
                             "/app/api/v1/submissions/" +
                             URI.escape(source_submission_id) +
                             "/?include=values"
        puts "Getting from submission: #{submission_api_route}"
      # Retrieve the Submission Values
      submission_result = RestClient::Resource.new(
        submission_api_route,
        user: source_user,
        password: source_pass
      ).get

      puts "Got from submission: #{submission_api_route}"
      # If the submission exists
      unless submission_result.nil?
        submission = JSON.parse(submission_result)["submission"]
        field_value = submission["values"][source_field_name]
        # If the attachment field value exists
        unless field_value.nil?
          files = []
          # Attachment field values are stored as arrays, one map for each file attachment
          field_value.each_index do |index|
            file_info = field_value[index]
            tmp_file_name = File.join(@tmp_dir, file_info['name'])
            # The attachment file name is stored in the 'name' property
            # API route to get the generated attachment download link from Kinetic Request CE.
            # "/{spaceSlug}/app/api/v1/submissions/{submissionId}/files/{fieldName}/{fileIndex}/{fileName}/url"

            attachment_download_api_route = source_server +
              '/app/api/v1' +
              '/submissions/' + URI.escape(source_submission_id) +
              '/files/' + URI.escape(source_field_name) +
              '/' + index.to_s +
              '/' + URI.escape(file_info['name']) +
              '/url'
            puts "Getting attachment from submission: #{file_info['name']} from field #{source_field_name}" if @enable_debug_logging
            # Retrieve the URL to download the attachment from Kinetic Request CE.
            # This URL will only be valid for a short amount of time before it expires
            # (usually about 5 seconds).
            attachment_download_result = RestClient::Resource.new(
              attachment_download_api_route,
              user: source_user,
              password: source_pass
            ).get

            unless attachment_download_result.nil?
                # get the filehub url to download the file
                fileUrl = JSON.parse(attachment_download_result)['url']
                puts "Downloading file: #{file_info['name']} from #{fileUrl}" if @enable_debug_logging

                puts "Downloading file to memory" if @enable_debug_logging
                file_content = RestClient.get(fileUrl).to_java_bytes


                # upload the handler file to the space task source_server
                http_client = DefaultHttpClient.new
                httppost = HttpPost.new("#{destination_server}/#{destination_kapp_slug}/#{destination_form_slug}/files")
                httppost.setHeader("Authorization", "Basic " + Base64.encode64(destination_user + ':' + destination_pass).gsub("\n",''))
                httppost.setHeader("Accept", "application/json")
                reqEntity = MultipartEntity.new
                mime_type = MIME::Types.type_for(file_info['name']).first.content_type
                if mime_type.nil?
                  mime_type = "text/plain"
                end
                byte = ByteArrayBody.new(file_content, mime_type, file_info['name'])
                reqEntity.addPart("file", byte)
                httppost.setEntity(reqEntity)
                puts "Sending the request to import the handler" if @enable_debug_logging
                response = http_client.execute(httppost)
                entity = response.getEntity
                resp = EntityUtils.toString(entity)
                jsonfileDetails = JSON.parse(resp)[0]
                imported_file_details.push(jsonfileDetails)

                # remove the downloaded file
                FileUtils.rm tmp_file_name, :force => true

                # add the name of the handler file to the result variable
                imported_files << file_info['name']

            end

            file_info.delete("link")
            files << file_info
          end
            #now we have the file uploaded, we need to attach it to the specific submission and field
            api_route = "#{destination_server}/app/api/v1/submissions/#{destination_submission_id}"

            puts "Update submission API ROUTE: #{api_route}" if @enable_debug_logging

            resource = RestClient::Resource.new(api_route, { :user => destination_user, :password => destination_pass })
            values = {destination_field_name => imported_file_details}
            # Building the object that will be sent to Kinetic Core
            data = {}
            data.tap do |json|
              json[:values] = values
            end
            # Post to the API
            puts "Posting #{values.to_json} to submission #{destination_submission_id}" if @enable_debug_logging
            result = resource.put(data.to_json, { :accept => "json", :content_type => "json" })
        end

            puts "Returning results" if @enable_debug_logging
            return <<-RESULTS
            <results>
              <result name="Handler Error Message"></result>
              <result name="Files">#{ERB::Util.html_escape(imported_files.to_json)}</result>
              <result name="Space Slug">#{destination_space_slug}</result>
            </results>
            RESULTS
      end

    puts "Returning results" if @enable_debug_logging
    return <<-RESULTS
    <results>
      <result name="Handler Error Message"></result>
      <result name="Files">#{ERB::Util.html_escape(imported_files.to_json)}</result>
      <result name="Space Slug">#{destination_space_slug}</result>
    </results>
    RESULTS

    rescue RestClient::Exception => error
      #error_message = JSON.parse(error.response)["message"]
      error_message = error
      if error_handling == "Raise Error"
        raise error_message
      else
        return <<-RESULTS
        <results>
          <result name="Handler Error Message">#{error.http_code}: #{ERB::Util.html_escape(error_message)}</result>
          <result name="Files">#{ERB::Util.html_escape(imported_files.to_json)}</result>
          <result name="Space Slug">#{destination_space_slug}</result>
        </results>
        RESULTS
      end
  end

end
