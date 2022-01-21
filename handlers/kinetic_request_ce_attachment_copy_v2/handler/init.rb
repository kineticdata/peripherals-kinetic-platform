require 'erb'
require 'fileutils'
require 'json'
require 'securerandom'
require 'tmpdir'

require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))
require File.expand_path(File.join(File.dirname(__FILE__), 'helpers_http'))


class KineticRequestCeAttachmentCopyV2

  include HandlerHelpers::Http

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

    @enable_debug_logging = ["yes", "true"].include?(@info_values['enable_debug_logging'].downcase)
    @raise_error = @parameters["error_handling"] == "Raise Error"

    puts "Parameters: #{@parameters.inspect}" if @enable_debug_logging
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

    #Server Variables
    user             = @info_values["api_username"]
    pass             = @info_values["api_password"]
    kapp_slug        = @parameters["kapp_slug"]
    form_slug        = @parameters["form_slug"]
    #Source Submission Variables
    submission_id    = @parameters["submission_id"]
    field_name       = @parameters["field_name"]
    #Destination Submission Variables
    to_submission_id = @parameters["to_submission_id"]
    to_field_name    = @parameters["to_field_name"]
    #Other Variables
    imported_files = []         # used in handler results
    imported_file_details = []  # used in the destination submission field value

    # Headers for server: Authorization, Accept, Content-Type
    headers = http_basic_headers(user, pass)


    # Retrieve the source submission
    puts "Retrieving source submission: #{submission_id}" if @enable_debug_logging
    # Submission API Route
    source_submission_route = "#{server}/app/api/v1/submissions/#{submission_id}/?include=values"
    # Retrieve the submission and values
    res = http_get(source_submission_route, { "include" => "values" }, headers)
    if !res.kind_of?(Net::HTTPSuccess)
      message = "Failed to retrieve source submission #{submission_id}"
      return handle_exception(message, res)
    end
    submission = JSON.parse(res.body)["submission"]
    puts "Received source submission #{submission['id']}" if @enable_debug_logging


    # Check if the there are any attachments in the source field
    field_value = submission["values"][field_name]

    # If the attachment field value exists
    if !field_value.nil?
      # Attachment field values are stored as arrays, one map for each file attachment.
      #
      # This isn't the real attachment info though, this is just metadata about the attachment
      # that can be retrieved to get a link to the attachment in Filehub.
      #
      # Process each attachment file
      field_value.each_with_index do |attachment_info, index|
        begin
          # The attachment file name is stored in the 'name' property
          attachment_name = attachment_info['name']

          # Temporary file to stream contents to
          tempdir = "#{Dir.tmpdir}/#{SecureRandom.hex(8)}"
          tempfile = "#{tempdir}/#{attachment_name}"
          FileUtils.mkdir_p(tempdir)


          # Retrieve the attachment download link from the server
          puts "Retrieving attachment download link from source submission: #{attachment_name} for field #{field_name}" if @enable_debug_logging

          # API route to get the generated attachment download link from Kinetic Request CE.
          # "/{spaceSlug}/app/api/v1/submissions/{submissionId}/files/{fieldName}/{fileIndex}/{fileName}/url"
          download_link_api_route = "#{server}/app/api/v1" <<
            "/submissions/#{submission_id}" <<
            "/files/#{URI.escape(field_name)}" <<
            "/#{index.to_s}/#{URI.escape(attachment_name)}/url"


          # Retrieve the URL to download the attachment from Kinetic Request CE.
          # This URL will only be valid for a short amount of time before it expires
          # (usually about 5 seconds).
          res = http_get(download_link_api_route, {}, headers)
          if !res.kind_of?(Net::HTTPSuccess)
            message = "Failed to retrieve link for attachment #{attachment_name} from source submission"
            return handle_exception(message, res)
          end
          file_download_url = JSON.parse(res.body)['url']
          puts "Received link for attachment #{attachment_name} from source submission" if @enable_debug_logging


          # Download the attachment from the source submission
          puts "Downloading attachment #{attachment_name} from #{file_download_url}" if @enable_debug_logging
          res = stream_file_download(tempfile, file_download_url, {}, headers)
          if !res.kind_of?(Net::HTTPSuccess)
            message = "Failed to download attachment #{attachment_name} from the server"
            return handle_exception(message, res)
          end

          # Upload the attachment to the destination submission
          file_upload_url = "#{server}/#{kapp_slug}/#{form_slug}/files"
          puts "Uploading attachment file: #{attachment_name} to #{file_upload_url}" if @enable_debug_logging
          res = upload_file(tempfile, file_upload_url, {}, headers)
          if !res.kind_of?(Net::HTTPSuccess)
            message = "Failed to upload attachment #{attachment_name} to the server"
            return handle_exception(message, res)
          end
          file_upload_details = JSON.parse(res.body)[0]

          # add the uploaded attachment info to the array of imported file details
          puts "Uploaded attachment details: #{file_upload_details}"
          imported_file_details.push(file_upload_details)


          # add the name of the attachment to the result variable
          imported_files << attachment_name
        ensure
          # Remove the temp directory along with the downloaded attachment
          FileUtils.rm_rf(tempdir)
        end
      end
    else
      puts "Source submission attachment field value is empty: #{field_name}" if @enable_debug_logging
    end

    results = handle_results(space_slug, "", imported_files)
    puts "Returning results: #{results}" if @enable_debug_logging
    results
  end


  def handle_results(space_slug, error_msg, files)
    <<-RESULTS
    <results>
      <result name="Handler Error Message">#{ERB::Util.html_escape(error_msg)}</result>
      <result name="Files">#{ERB::Util.html_escape(files.to_json)}</result>
      <result name="Space Slug">#{ERB::Util.html_escape(space_slug)}</result>
    </results>
    RESULTS
  end



  def handle_exception(message, error)
    if error.is_a? java.io.IOException
      error_message = "#{message}: #{error.get_message}"
      error_message << " caused by: #{error.get_cause.get_message}" if !error.get_cause.nil?
    elsif error.is_a? Net::HTTPResponse
      error_message = "#{message}: #{error.code} #{error.message}"
    elsif error.respond_to? :message
      error_message = "#{message}: #{error.message}"
    else
      error_message = "#{message}: #{error.inspect}"
    end
    puts error_message
    raise error_message if @raise_error
    handle_results(nil, error_message, nil)
  end

end
