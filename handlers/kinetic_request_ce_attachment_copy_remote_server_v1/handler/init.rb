require "base64"
require 'erb'
require 'fileutils'
require 'json'
require 'net/https'
require 'securerandom'
require 'tmpdir'


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

    @enable_debug_logging = ["yes", "true"].include?(@info_values['enable_debug_logging'].downcase)
    @raise_error = @parameters["error_handling"] == "Raise Error"

    puts "Parameters: #{@parameters.inspect}" if @enable_debug_logging
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
    imported_files = []         # used in handler results
    imported_file_details = []  # used in the destination submission field value


    # Headers for each server: Authorization, Accept, Content-Type
    dest_headers = http_basic_headers(destination_user, destination_pass)
    source_headers = http_basic_headers(source_user, source_pass)


    # Retrieve the source submission
    puts "Retrieving source submission #{source_submission_id}" if @enable_debug_logging
    # Submission API Route
    source_submission_route = "#{source_server}/app/api/v1/submissions/#{source_submission_id}/?include=values"
    # Retrieve the submission and values
    res = http_get(source_submission_route, { "include" => "values" }, source_headers)
    if !res.kind_of?(Net::HTTPSuccess)
      message = "Failed to retrieve source submission #{source_submission_id}"
      return handle_exception(message, res)
    end
    submission = JSON.parse(res.body)["submission"]
    puts "Received source submission #{submission['id']}" if @enable_debug_logging
  

    # Check if the there are any attachments in the source field
    field_value = submission["values"][source_field_name]


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


          # Retrieve the attachment download link from the source server
          puts "Retrieving attachment download link from source submission: #{attachment_name} for field #{source_field_name}" if @enable_debug_logging
          # API route to get the generated attachment download link from Kinetic Request CE.
          # "/{spaceSlug}/app/api/v1/submissions/{submissionId}/files/{fieldName}/{fileIndex}/{fileName}/url"
          download_link_api_route = "#{source_server}/app/api/v1" <<
            "/submissions/#{source_submission_id}" <<
            "/files/#{URI.escape(source_field_name)}" <<
            "/#{index.to_s}/#{URI.escape(attachment_name)}/url"

          # Retrieve the URL to download the attachment from Kinetic Request CE.
          # This URL will only be valid for a short amount of time before it expires
          # (usually about 5 seconds).
          res = http_get(download_link_api_route, {}, source_headers)
          if !res.kind_of?(Net::HTTPSuccess)
            message = "Failed to retrieve link for attachment #{attachment_name} from source submission"
            return handle_exception(message, res)
          end
          file_download_url = JSON.parse(res.body)['url']
          puts "Received link for attachment #{attachment_name} from source submission" if @enable_debug_logging


          # Download the attachment from the source server
          puts "Downloading attachment #{attachment_name} from #{file_download_url}" if @enable_debug_logging
          res = stream_file_download(tempfile, file_download_url, {}, source_headers)
          if !res.kind_of?(Net::HTTPSuccess)
            message = "Failed to download attachment #{attachment_name} from the source server"
            return handle_exception(message, res)
          end


          # Upload the attachment to the destination server
          file_upload_url = "#{destination_server}/#{destination_kapp_slug}/#{destination_form_slug}/files"
          puts "Uploading attachment file: #{attachment_name} to #{file_upload_url}" if @enable_debug_logging
          res = stream_file_upload(tempfile, file_upload_url, {}, dest_headers)
          if !res.kind_of?(Net::HTTPSuccess)
            message = "Failed to upload attachment #{attachment_name} to the destination server"
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


      # Update the submission on the destination server
      destination_submission_route = "#{destination_server}/app/api/v1/submissions/#{destination_submission_id}"
      puts "Update submission #{destination_submission_id} on the destination server: #{destination_submission_route}" if @enable_debug_logging

      payload = { values: { destination_field_name => imported_file_details } }
      res = http_put(destination_submission_route, payload, {}, dest_headers)
      if !res.kind_of?(Net::HTTPSuccess)
        message = "Failed to update submission #{destination_submission_id} on the destination server"
        return handle_exception(message, res)
      end

    else
      puts "Submission attachment field value is empty on the source server: #{source_field_name}" if @enable_debug_logging
    end

    results = handle_results(destination_space_slug, "", imported_files)
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
    case error
    when Net::HTTPResponse
      begin
        content = JSON.parse(error.body)
        error_key = content["errorKey"] || error.code
        error_msg = content["error"] || ""
        error_message = "#{message}:\n\tError Key: #{error_key}\n\tError: #{error_msg}"
      rescue StandardError => e
        error_key = error.code
        error_message = "#{message}:\n\tError Key: #{error_key}\n\tError: #{error.body}"
      end
    when NilClass
      error_message = "0: No response from server"
    else
      error_message = "Unexpected error: #{error.inspect}"
    end
    puts error_message
    raise error_message if @raise_error
    handle_results(nil, error_message, nil)
  end



  #-----------------------------------------------------------------------------
  # The following Http helper methods are provided within this handler because
  # task currently doesn't have a common http client module that handlers can
  # use. If these methods were packaged as a module within the dependencies.rb
  # file or within a gem/library, they would be under the same constraints as
  # other vendor gems, such as RestClient, where any handler that uses
  # RestClient is currently stuck using v1.6.7. Adding these methods
  # directly to the handler class gives the freedom to add/modify as needed
  # without affecting other handlers.
  #-----------------------------------------------------------------------------


  #-----------------------------------------------------------------------------
  # HTTP HEADERS
  #-----------------------------------------------------------------------------

  def http_json_headers
    {
      "Accept" => "application/json",
      "Content-Type" => "application/json"
    }
  end
  
  
  def http_basic_headers(username, password)
    http_json_headers.merge({
      "Authorization" => "Basic #{Base64.strict_encode64("#{username}:#{password}")}"
    })
  end


  #-----------------------------------------------------------------------------
  # REST ACTIONS
  #-----------------------------------------------------------------------------

  def http_delete(url, payload, parameters, headers, http_options={})
    uri = URI.parse(url)
    uri.query = URI.encode_www_form(parameters) unless parameters.empty?
    request = Net::HTTP::Delete.new(uri, headers)
    request.body = payload.to_json unless payload.nil? || payload.kind_of?(String)
    send_request(request, http_options)
  end
  
  
  def http_get(url, parameters, headers, http_options={})
    uri = URI.parse(url)
    uri.query = URI.encode_www_form(parameters) unless parameters.empty?
    request = Net::HTTP::Get.new(uri, headers)
    send_request(request, http_options)
  end
  
  
  def http_post(url, payload, parameters, headers, http_options={})
    payload = payload.to_json unless payload.is_a? String
    uri = URI.parse(url)
    uri.query = URI.encode_www_form(parameters) unless parameters.empty?
    request = Net::HTTP::Post.new(uri, headers)
    request.body = payload
    send_request(request, http_options)
  end
  
  
  def http_put(url, payload, parameters, headers, http_options={})
    payload = payload.to_json unless payload.is_a? String
    uri = URI.parse(url)
    uri.query = URI.encode_www_form(parameters) unless parameters.empty?
    request = Net::HTTP::Put.new(uri, headers)
    request.body = payload
    send_request(request, http_options)
  end


  #-----------------------------------------------------------------------------
  # ATTACHMENT METHODS
  #-----------------------------------------------------------------------------

  def stream_file_download(file, url, parameters, headers, http_options={})
    uri = URI.parse(url)
    uri.query = URI.encode_www_form(parameters) unless parameters.empty?

    http = build_http(uri, http_options)
    request = Net::HTTP::Get.new(uri, headers)

    http.request(request) do |response|
      open(file, 'w') do |io|
        response.read_body do |chunk|
          io.write chunk
        end
      end
    end
  end


  def stream_file_upload(file, url, parameters, headers, http_options={})
    uri = URI.parse(url)
    uri.query = URI.encode_www_form(parameters) unless parameters.empty?

    request = Net::HTTP::Post.new(uri, headers)
    request.set_form([[ "f", File.open(file) ]], "multipart/form-data")

    Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
      configure_http(http, http_options)
      http.request(request)
    end
  end


  #-----------------------------------------------------------------------------
  # LOWER LEVEL METHODS
  #-----------------------------------------------------------------------------

  def send_request(request, http_options={})
    uri = request.uri
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
      configure_http(http, http_options)
      http.request(request)
    end
  end
  
  
  def build_http(uri, http_options={})
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl= true if (uri.scheme == 'https')
    configure_http(http, http_options)
    http
  end


  def configure_http(http, http_options={})
    http_options_sym = (http_options || {}).inject({}) { |h, (k,v)| h[k.to_sym] = v; h }
    http.verify_mode = http_options_sym[:ssl_verify] || OpenSSL::SSL::VERIFY_PEER if http.use_ssl?
    http.read_timeout= http_options_sym[:read_timeout] unless http_options_sym[:read_timeout].nil?
    http.open_timeout= http_options_sym[:open_timeout] unless http_options_sym[:open_timeout].nil?
  end

end
