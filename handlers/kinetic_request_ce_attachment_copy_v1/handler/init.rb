require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class KineticRequestCeAttachmentCopyV1
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
    space_slug = @parameters["space_slug"].empty? ? @info_values["space_slug"] : @parameters["space_slug"]
    if @info_values['api_server'].include?("${space}")
      server = @info_values['api_server'].gsub("${space}", space_slug)
    elsif !space_slug.to_s.empty?
      server = @info_values['api_server']+"/"+space_slug
    else
      server = @info_values['api_server']
    end

    user            = @info_values["api_username"]
    pass            = @info_values["api_password"]
    error_handling  = @parameters["error_handling"]
    kapp_slug       = @parameters["kapp_slug"]
    form_slug       = @parameters["form_slug"]
    submission_id        = @parameters["submission_id"]
    to_submission_id        = @parameters["to_submission_id"]
    to_field_name        = @parameters["to_field_name"]
    field_name      = @parameters["field_name"]
    imported_files = []
    imported_file_details = []

     # Submission API Route including Values
      submission_api_route = server +
                             "/app/api/v1/submissions/" +
                             URI.escape(submission_id) +
                             "/?include=values"
        puts "Getting from submission: #{submission_api_route}"
      # Retrieve the Submission Values
      submission_result = RestClient::Resource.new(
        submission_api_route,
        user: user,
        password: pass
      ).get

      puts "Got from submission: #{submission_api_route}"
      # If the submission exists
      unless submission_result.nil?
        submission = JSON.parse(submission_result)["submission"]
        field_value = submission["values"][field_name]
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

            attachment_download_api_route = server +
              '/app/api/v1' +
              '/submissions/' + URI.escape(submission_id) +
              '/files/' + URI.escape(field_name) +
              '/' + index.to_s +
              '/' + URI.escape(file_info['name']) +
              '/url'
            puts "Getting attachment from submission: #{file_info['name']} from field #{field_name}" if @enable_debug_logging
            # Retrieve the URL to download the attachment from Kinetic Request CE.
            # This URL will only be valid for a short amount of time before it expires
            # (usually about 5 seconds).
            attachment_download_result = RestClient::Resource.new(
              attachment_download_api_route,
              user: user,
              password: pass
            ).get

            unless attachment_download_result.nil?
                # get the filehub url to download the file
                fileUrl = JSON.parse(attachment_download_result)['url']
                puts "Downloading file: #{file_info['name']} from #{fileUrl}" if @enable_debug_logging

                puts "Downloading file to memory" if @enable_debug_logging
                file_content = RestClient.get(fileUrl).to_java_bytes


                # upload the handler file to the space task server
                http_client = DefaultHttpClient.new
                httppost = HttpPost.new("#{server}/#{kapp_slug}/#{form_slug}/files")
                httppost.setHeader("Authorization", "Basic " + Base64.encode64(user + ':' + pass).gsub("\n",''))
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
            api_route = "#{server}/app/api/v1/submissions/#{to_submission_id}"

            puts "Update submission API ROUTE: #{api_route}" if @enable_debug_logging

            resource = RestClient::Resource.new(api_route, { :user => user, :password => pass })
            values = {to_field_name => imported_file_details}
            # Building the object that will be sent to Kinetic Core
            data = {}
            data.tap do |json|
              json[:values] = values
            end
            # Post to the API
            puts "Posting #{values.to_json} to submission #{to_submission_id}" if @enable_debug_logging
            result = resource.put(data.to_json, { :accept => "json", :content_type => "json" })
        end

            puts "Returning results" if @enable_debug_logging
            return <<-RESULTS
            <results>
              <result name="Handler Error Message"></result>
              <result name="Files">#{ERB::Util.html_escape(imported_files.to_json)}</result>
              <result name="Space Slug">#{space_slug}</result>
            </results>
            RESULTS
      end

    puts "Returning results" if @enable_debug_logging
    return <<-RESULTS
    <results>
      <result name="Handler Error Message"></result>
      <result name="Files">#{ERB::Util.html_escape(imported_files.to_json)}</result>
      <result name="Space Slug">#{space_slug}</result>
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
          <result name="Space Slug">#{space_slug}</result>
        </results>
        RESULTS
      end
  end

end
