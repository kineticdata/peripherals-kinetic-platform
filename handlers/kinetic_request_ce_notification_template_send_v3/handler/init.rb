# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), "dependencies"))

class KineticRequestCeNotificationTemplateSendV3
  # Prepare for execution by building Hash objects for necessary values and
  # validating the present state.  This method sets the following instance
  # variables:
  # * @input_document - A REXML::Document object that represents the input Xml.
  # * @info_values - A Hash of info names to info values.
  # * @parameters - A Hash of parameter names to parameter values.
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Parameters
  # * +input+ - The String of Xml that was built by evaluating the node.xml
  #   handler template.
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

    # Retrieve the info values
    @smtp_server      =   @info_values['smtp_server']
    @smtp_port        =   @info_values['smtp_port'] || '25'
    @smtp_tls         =   @info_values['smtp_tls'].downcase == 'true'
    @smtp_username    =   @info_values['smtp_username']
    @smtp_password    =   @info_values['smtp_password']
    @smtp_from        =   @info_values['smtp_from_address']
    @smtp_auth_type   =   @info_values['smtp_auth_type']&.strip&.downcase
    @api_username     =   URI.encode(@info_values['api_username'])
    @api_password     =   @info_values['api_password']
    @tenant_id        =   @info_values['tenant_id']


    # Determine if debug logging is enabled
    @debug_logging_enabled = @info_values["enable_debug_logging"] == 'Yes'
    puts("Logging enabled.") if @debug_logging_enabled

    @error_handling   = @parameters["error_handling"]

    # Create placeholder variables used throughout the handler
    @snippets         = []
    @snippet_re       = /\$\{snippet\(\'(.*?)\'\)}/
    @recipient_json   = {}
    @message          = {'email' => nil, 'subject' => nil, 'html' => nil, 'text' => nil}
    @replace_values   = JSON.parse(@parameters['replacement_values'])
    @replace_fields   = ['Subject', 'HTML Content', 'Text Content']
    @date_format_json = {}
    @error_message    = ''
    @template_name    = @parameters['notification_template_name']
    @submission_id    = @parameters['submission_id']

  end

  # The execute method gets called by the task engine when the handler's node is processed. It is
  # responsible for performing whatever action the name indicates.
  # If it returns a result, it will be in a special XML format that the task engine expects. These
  # results will then be available to subsequent tasks in the process.
  def execute
    space_slug = @parameters["space_slug"].empty? ? @info_values["space_slug"] : @parameters["space_slug"]
    if @info_values['api_server'].include?("${space}")
      @api_server = @info_values['api_server'].gsub("${space}", space_slug)
    elsif !space_slug.to_s.empty?
      @api_server = @info_values['api_server']+"/"+space_slug
    else
      @api_server = @info_values['api_server']
    end

    # Build Recipient JSON Based on input value. If not JSON, assume it's an email address
    begin
      @recipient_json = JSON.parse(@parameters["recipient_json"])
      
    rescue
       @recipient_json =  { "smtpaddress" => {"to" => @parameters["recipient_json"]}, "type" => "smtp", "email notifications" => 'yes' }

    end
    
    # Check for a legacy format where smtpaddress was a string. Make correction to convert smtpaddress to an object.
    @recipient_json["smtpaddress"] =  {"to" => @recipient_json["smtpaddress"]} if @recipient_json["smtpaddress"].is_a?(String)
      
    # Build Up Template with snippet Replacements
    template_to_use = mergeTemplateAndsnippets(@template_name)

    # Get Valid Date formats from CE
    getDateFormats()

    # Replace Content in Subject, HTML Body, Text Body if a Template was found
    template_to_use["Subject"] = apply_replacements(template_to_use["Subject"])
    template_to_use["HTML Content"] = apply_replacements(template_to_use["HTML Content"])
    template_to_use["Text Content"] = apply_replacements(template_to_use["Text Content"])

    ################################################
    ##  SEND EMAIL AND CREATE NOTIFICATION IN CE  ##
    ################################################
    if @smtp_auth_type.nil? || @smtp_auth_type.empty?
      log("No authentication type, closing","error")
        results = "<results>\n"
        results += "  <result name='Handler Error Message'>No authentication type provided (#{@smtp_auth_type})</result>\n"
        results += "  <result name='Email Id'></result>\n"
        results += "</results>"
        return results
    end
    # Check to make sure a valid message template was found
    if !template_to_use.nil?


      # If the User has an email address and want to receive notifications
      email_results = {}
      if (!@recipient_json["smtpaddress"].to_s.empty? || !@recipient_json["smtpaddress_cc"].to_s.empty? || !@recipient_json["smtpaddress_bcc"].to_s.empty?) && @recipient_json["email notifications"].to_s.downcase != 'no'
        #Graph API
        if(@smtp_auth_type == 'graph')
          auth = {
            :type           => 'graph',
            :tenant_id      => @tenant_id,
            :client_id      => @smtp_username,
            :client_secret  => @smtp_password,
            :from           => @smtp_from
          }
          email_results = sendEmailMessage(template_to_use, auth)
        else
          email_results = sendEmailMessage(template_to_use)
        end

      else
        @error_message = @error_message + "\nNo Email Address or CE User was provided"
      end

      # Returning Results With Success
      results = "<results>\n"
      results += "  <result name='Handler Error Message'>#{escape(@error_message)}</result>\n"
      results += "  <result name='Email Id'>#{escape(email_results['message_id'])}</result>\n"
      results += "</results>"
    else
      @error_message = "Notification template \"#{@template_name}\" could not be found."
      # Returning Results With Failure
      results = "<results>\n"
      results += "  <result name='Handler Error Message'>#{escape(@error_message)}</result>\n"
      results += "  <result name='Email Id'></result>\n"
      results += "</results>"
    end
    return results
  end

  ##########################################################################
  ####  USED FOR RETRIEVING A RECORD BY NAME FROM CE NOTIFICATION DATA  ####
  ##########################################################################
  def mergeTemplateAndsnippets(templateName)
    puts "Merging Template and snippet Records for #{templateName}" if @debug_logging_enabled
    # Get the Initial Record
    record = getNotificationRecord(templateName)

    # Return nil if no Template was found
    if record.nil?
      return record
    else
    # Return Record with snippets Replaced
      return replacesnippetsInRecord(record)
    end
  end

  ##########################################################################
  ####  USED FOR RETRIEVING A RECORD BY NAME FROM CE NOTIFICATION DATA  ####
  ##########################################################################
  def getNotificationRecord(templateName)
    puts "Getting Notification Record: #{templateName}" if @debug_logging_enabled
    # Build up a query to retrieve the appropriate notification template
    query = %|values[Name]="#{templateName}" AND values[Status]="Active"|
    # Build the API route for retrieving the notification template submissions based on the Query
    route =  "#{@api_server}/app/api/v1/datastore/forms/notification-data/submissions" +
                      "?include=details,values&limit=1000&index=values[Name],values[Status]&q=#{URI.escape(query)}"
    # Build a rest resource for calling the CE API
    # puts "from route: #{route}" if @debug_logging_enabled
    resource = RestClient::Resource.new(route, { :user => @api_username, :password => @api_password })
    # Retrieve template records from the CE API
    records = JSON.parse(resource.get)["submissions"]
    # Find the Record that matches the users preferences
    record = findClosestMatch(records, templateName)
    # Recursively Find all snippets and Return the Final Content
    return record
  end


  ##########################################################################
  ####  METHOD USED FOR DETERMINING WHICH TEMPLATE / snippet TO CHOOSE  ####
  ##########################################################################
  def findClosestMatch(records, templateName)
    # Build a placeholder to store the selected notification template
    selected_record = nil
    recipient_language = @recipient_json['language'].to_s
    recipient_region = @recipient_json['region'].to_s

    # Return an error if no notification template was found
    if records.length == 0
      @error_message = "The following Notification Template or snippet was not located: #{templateName}\n\n"
    # If only one template is returned, or the user has no preferences use the first match
    elsif records.length == 1 || (recipient_language.empty? && recipient_region.empty?)
        selected_record = records[0]['values']
        puts "Only one record returned for #{templateName}, OR no preferences found so selected first" if @debug_logging_enabled
    else
    # Select a template based on users preferences
    # Define an array of preferences for each record returned
      recordPreferences = records.map do |record|
        {
          'id' => record['id'],
          'language' => record['values']['Language'],
          'region' => record['values']['Region'],
          'score' => 0,
        }
      end
      # Loop over each record and try to match it
      recordPreferences.each do |record|
        language = record['language'].to_s
        region = record['region'].to_s
        # Test to see if both language and region match if neither are empty
        if recipient_language == language && recipient_region == region && (!recipient_region.empty? && !region.empty?) && (!recipient_language.empty? && !language.empty?)
          record['score'] += 3
          puts "Matched on Language and Region for Template #{templateName}" if @debug_logging_enabled
        # Test to see if a language matches if they are not empty
        elsif recipient_language == language && (!recipient_language.empty? && !language.empty?)
          record['score'] += 2
          puts "Matched on Language only for Template #{templateName}" if @debug_logging_enabled
        # Test to see if a region matches
        elsif recipient_region == region && (!recipient_region.empty? && !region.empty?)
          record['score'] += 1
          puts "Matched on Region only for Template #{templateName}" if @debug_logging_enabled
        end
        puts "Score is #{record['score']} for Template #{templateName}" if @debug_logging_enabled
      end

      # Determine which record should be choosen as the selected record
      closestMatch = recordPreferences.max_by { |element| element['score'] }
      # Get the ID so we can select this record. If multiple had the same score, choose the first
      closestMatch.kind_of?(Array) ? closestMatch = closestMatch[0]['id'] : closestMatch = closestMatch['id']
      # Set the selected record to be returned
      selected_record = records.find { |match| match['id'] == closestMatch }['values']
    end
    # Return the selected record
    return selected_record
  end

  ##########################################################################
  ####     METHOD USED FOR REPLACING SNIPPETS IN A GIVEN NOTIFICATION   ####
  ##########################################################################
  def replacesnippetsInRecord(record)
    puts "Replacing snippets In Record" if @debug_logging_enabled
    # Create a placeholder to store the
    snippetNames = []
    snippetRecords = []

    # Loop Over the Subject, HTML, Text of each Record and find snippets if a value exists
    record.each do |field, value|
      if !value.nil?
        # Add Unique snippets to the snippetNames Array
        value.scan(@snippet_re).flatten.uniq.each do |snippetName|
          snippetNames.push snippetName
        end
      end
    end

    # Retrieve Each snippet Found from the CE API and store them in the snippetsRecords Array
    snippetNames.flatten.uniq.each do |snippetName|
      snippetRecords.push(getNotificationRecord(snippetName))
    end

    # Loop Over the Subject, HTML, Text of each Record and replace snippets if they were found
    record.each do |field, value|
      if @replace_fields.include?(field) && !value.to_s.empty?
        value.scan(@snippet_re).flatten.uniq.each do |snippetName|
          # Do Rest Call to get snippet
          snippetRecord = snippetRecords.find { |snippet| snippet != nil && snippet["Name"] == snippetName }
          # If a snippet record is found, replace it
          if !snippetRecord.to_s.empty?
            # If it's an HTML field, use the HTML Content from the snippet
            if field.include? "HTML"
              record[field].gsub!("${snippet('#{snippetName}')}", snippetRecord["HTML Content"])
            else  # Otherwise, use the Text Content (Subject / Text)
              record[field].gsub!("${snippet('#{snippetName}')}", snippetRecord["Text Content"])
            end
          end
        end
      end
    end
    return record
  end

  ##########################################################################
  ####                  Perform Replacements.                           ####
  ##########################################################################
  def apply_replacements(content)
    puts "Applying Replacements for Content" if @debug_logging_enabled
    #Extract the keys from the replacement_values attribute
    @replace_values.keys.each{|key|
      content = content.gsub(/\$\{#{key}\('(.*?)'\)\}/) do
        if @replace_values[key].has_key?($1)
          @replace_values[key][$1]
        else
          "${#{key}('#{$1}')}"
        end
      end
    }

    #Replace Dates
    #This does a "negative look ahead" to ensure it captures the entire quote string
    content = content.gsub(/\$\{appearance\('(.*?)'\)\}(?!('\)\}))/) do
      #need to split into content and ${format()} sections
      thisContent=$1.split("$")
      #check if tag matches a valid date and if so convert first part into date and format it.
      thisDateFormat = thisContent[1].gsub(/\{format\('(.*?)'\)\}/) do
        if @date_format_json.has_key?($1)
          @date_format_json[$1]['Format']
        else
          '${format(\''+$1+'\')}'
        end
      end
      if !thisDateFormat.nil? && !thisDateFormat.include?('{format')
        if thisDateFormat.include?('%')
          begin
            d = DateTime.parse(thisContent[0])
            d.strftime(thisDateFormat)
          rescue
            thisContent[0].to_s
          end
        end
      else
        '${appearance(\''+thisContent[0]+'$'+thisDateFormat+'\')}'
      end
    end

    return content
  end

  def apply_attachments(mail, attachmentList)
    if @submission_id.nil? || @submission_id.empty?
      raise "Related submission required for adding attachments"
    end

    puts "Applying attachments" if @debug_logging_enabled
    #Extract the keys from the replacement_values attribute
     
   
     # determine this file's current directory
    pwd = File.dirname(File.expand_path(__FILE__))

    # create the temp file directory if it doesn't exist
    @tmp_dir = File.join(pwd, 'tmp_filecopy_zips')
    FileUtils.mkdir_p @tmp_dir
    
    # Submission API Route including Values
    submission_api_route = @api_server +
                            "/app/api/v1/submissions/" +
                            URI.escape(@submission_id) +
                            "/?include=values"
      puts "Getting from submission: #{submission_api_route}" if @debug_logging_enabled
    # Retrieve the Submission Values
    submission_result = RestClient::Resource.new(
      submission_api_route,
      user: @api_username,
      password: @api_password
    ).get

    puts "Got from submission: #{submission_api_route}" if @debug_logging_enabled
    # If the submission exists
    unless submission_result.nil?
      submission = JSON.parse(submission_result)["submission"]
      attachmentList.gsub(/\$\{attachment\('(.*?)'\)\}/) do
      field_value = submission["values"][$1]
      # If the attachment field value exists
      unless field_value.nil?
        # Attachment field values are stored as arrays, one map for each file attachment
        field_value.each_index do |index|
          file_info = field_value[index]
          tmp_file_name = File.join(@tmp_dir, file_info['name'])
          # The attachment file name is stored in the 'name' property
          # API route to get the generated attachment download link from Kinetic Request CE.
          # "/{spaceSlug}/app/api/v1/submissions/{submissionId}/files/{fieldName}/{fileIndex}/{fileName}/url"

          attachment_download_api_route = @api_server +
            '/app/api/v1' +
            '/submissions/' + URI.escape(@submission_id) +
            '/files/' + URI.escape($1) +
            '/' + index.to_s +
            '/' + URI.escape(file_info['name']) +
            '/url'
          
          puts "Getting attachment from submission: #{file_info['name']} from field #{$1}" if @debug_logging_enabled

          attachment_download_result = RestClient::Resource.new(
            attachment_download_api_route,
            user: @api_username,
            password: @api_password
          ).get

          unless attachment_download_result.nil?
              # get the filehub url to download the file
              file_url = JSON.parse(attachment_download_result)['url']
              puts "Downloading file: #{file_info['name']} from #{file_url}" if @debug_logging_enabled

              # In 2.x of core there was a redirect url that lasted 5 seconds.  
              # This was updated to a direct call to core post 2.x.  
              # Both legacy and modern are supported
              params = CGI.parse(URI(file_url).query || "")
              is_legacy = params.has_key?('signature') && params.has_key?('signature')
              puts "Using #{is_legacy ? "legacy" : "modern"} url" if @enable_debug_logging

              puts "Downloading file to memory" if @enable_debug_logging
              mail.attachments[file_info['name']] = is_legacy ? 
                RestClient.get(file_url).to_java_bytes : 
                RestClient::Resource.new(
                  file_url,
                  user: @api_username,
                  password: @api_password
                ).get().to_java_bytes
          end
        end
      end
    end
    
    end
    return mail
  end
  ##########################################################################
  ####                  Send Email using Template                       ####
  ##########################################################################
  def sendEmailMessage(template_to_use, auth={})
    puts "Sending Email Message to User" if @debug_logging_enabled
    #Prepare email data
    email_data = {
      :to           => @recipient_json["smtpaddress"]["to"],
      :cc           => @recipient_json["smtpaddress"]["cc"],
      :bcc          => @recipient_json["smtpaddress"]["bcc"],
      :from         => @smtp_from,
      :display_name => @smtp_from,
      :subject      => template_to_use["Subject"],
      :htmlbody     => template_to_use["HTML Content"],
      :textbody     => template_to_use["Text Content"]
    }



    #authentication       => @smtp_auth_type,
    if auth[:type] == 'graph'
      #Microsoft Graph Auth

      #Generate body
      payload = generate_payload(email_data)
      log( "Payload created", "debug")

      if !template_to_use["Attachments"].nil? && !template_to_use["Attachments"].empty?
        payload = apply_attachments_graph(payload, template_to_use["Attachments"])
        log("Attachments applied to payload", "debug")
      end
      if !email_data[:htmlbody].nil? && !email_data[:htmlbody].empty?
        payload = extract_and_embed_images_graph(payload, email_data[:htmlbody])
        log("Inline images embedded in payload", "debug")
      end

      return MicrosoftGraphEmail(auth,payload)

    else
      #Basic/plain auth
      return sendSMTPMessage(email_data,template_to_use)
    end

  end

  def sendSMTPMessage(email_details,template_to_use)
    # Unless there was not a user specified
    # Create SMTP Defaults hash
    begin
      smtp_defaults = {
        :address              => @smtp_server,
        :port                 => @smtp_port,
        :authentication       => @smtp_auth_type,
        :enable_starttls_auto => @smtp_tls
      }
      unless @smtp_username.nil? || @smtp_username.empty?
        # Set the email authentication
        smtp_defaults[:user_name] = @smtp_username
        smtp_defaults[:password]  = @smtp_password
      end

      Mail.defaults do
        delivery_method :smtp, smtp_defaults
      end

      
      mail = Mail.new do
        from          "#{email_details[:display_name]} <#{email_details[:from]}>"
        to            "#{email_details[:to]}"
        cc            "#{email_details[:cc]}"
        bcc           "#{email_details[:bcc]}"
        subject       "#{email_details[:subject]}"

        text_part do
          body "#{email_details[:textbody]}"
        end
      end
      
      # Embed linked images into the html body if present
      unless email_details[:htmlbody].nil? || email_details[:htmlbody].empty?
        mail = embed_images(email_details,mail)
      end
      
      if !template_to_use["Attachments"].nil?
        mail = apply_attachments(mail, template_to_use["Attachments"])
      end

      puts "Delivering the mail" if @debug_logging_enabled
      mail.deliver

      if !mail.bounced?
        puts "Mail message: #{mail.inspect}" if @debug_logging_enabled
        return { "message_id" => mail.message_id }
      else
        send_error = <<-LOGGING
          There was an error sending the email message
              Bounced?:        #{mail.bounced?}
              Final Recipient: #{mail.final_recipient}
              Action:          #{mail.action}
              Error Status:    #{mail.error_status}
              Diagnostic Code: #{mail.diagnostic_code}
              Retryable?:      #{mail.retryable}
          LOGGING

        puts send_error if @debug_logging_enabled
        @error_message = @error_message + send_error
        return { "message_id" => nil }
      end
    rescue Exception => e
      if @error_handling == "Raise Error"
        raise
      else
        send_error = "#{e.class.name} : #{e}"
        puts send_error if @debug_logging_enabled
        @error_message = @error_message + "\nSMTP Send #{@smtp_auth_type}\n" + send_error
        return { "message_id" => nil }
      end
    end
  end
  ##########################################################################
  ####                        Get DATE FORMATS                          ####
  ##########################################################################
  def getDateFormats()
    puts "Getting Date Formats" if @debug_logging_enabled
    begin
      # Retrieve all active date formats and populate the date_format_json object
      date_format_query = %|values[Status] IN ("active","Active")|
      date_format_api_route = "#{@api_server}/app/api/v1/datastore/forms/notification-template-dates/submissions" +
                  "?include=details,values&limit=1000&index=values[Status]&q=#{URI.escape(date_format_query)}"
      date_format_resource = RestClient::Resource.new(date_format_api_route, { :user => @api_username, :password => @api_password })
      date_format_response = date_format_resource.get
      JSON.parse(date_format_response)["submissions"].each{|format|
        @date_format_json[format["values"]["Name"]] = format["values"]
      }
      return true
    rescue RestClient::Exception => error
      error_message = nil
      begin
        error_message = JSON.parse(error.response)["error"]
      rescue
        error_message = error.inspect
      end
      puts "ERROR Getting Date Formats: #{error_message}" if @debug_logging_enabled
      if @error_handling == "Raise Error"
        raise error_message
      else
        @error_message = @error_message + "\nError Getting Date Formats: #{error.http_code}: #{escape(error_message)}"
        return false
      end
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

  def embed_url(mail, url)
    uri = URI.parse(url)
    filename = File.basename(uri.path)

    response = RestClient.get url
    mail.attachments[filename] = { :content => response.body, :content_type => response.headers[:content_type] }
    mail.attachments[filename].content_disposition("inline; name=\"#{filename}\"")

    return mail.attachments[filename].cid
  end

  #Microsoft Token renewal
  def MSAccessToken(tenant_id, client_id, client_secret)
      uri = URI("https://login.microsoftonline.com/#{tenant_id}/oauth2/v2.0/token")
      log( "URI: #{uri}")
      req = Net::HTTP::Post.new(uri)
      req.set_form_data({
        'client_id' => client_id,
        'scope' => 'https://graph.microsoft.com/.default',
        'client_secret' => client_secret,
        'grant_type' => 'client_credentials'
      })
      log( "Requesting token from Azure")
      log( "URI: #{uri.hostname} - port: #{uri.port}")
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
      if res.is_a?(Net::HTTPSuccess)
        log( "Req successful - #{res}")
      else
        log( "Req failed - #{res}", "error")
        raise "Failed to get token: #{res.body}"
      end
      log( "Returning token")

      return JSON.parse(res.body)['access_token']
  end

  #Log helper
  def log(message, log_level="info")
    unless @logtier
      @logtier = {"error" => 1, "debug" => 2, "info"=> 3}
      @current_log_level = @debug_logging_enabled ? "debug" : "info"
    end
    
    # Only log if the message level is equal to or more important than current level
    # Lower numbers = more important (error=1 is most important)
    puts "#{Time.now.utc} [#{log_level.upcase}] #{message}" if @logtier[log_level] <= @logtier[@current_log_level]
  end

  def MicrosoftGraphEmail(auth,payload)
    access_token = MSAccessToken(auth[:tenant_id], auth[:client_id], auth[:client_secret])
    log("Acces token retrieved","debug")
    sendURI = URI("https://graph.microsoft.com/v1.0/users/#{auth[:from]}/sendMail")
    
    req = Net::HTTP::Post.new(sendURI)
    req['Authorization'] = "Bearer #{access_token}"
    req['Content-Type'] = 'application/json'


    req.body = JSON.generate(payload)
    res = Net::HTTP.start(sendURI.hostname, sendURI.port, use_ssl: true) { |http| http.request(req) }
    log( "POST request sent","debug")
    if res.is_a?(Net::HTTPSuccess)
      log( "Email sent successfully!","debug")
    else
      log( "Failed to send email: #{res.code} #{res.body}", "error")
    end

    #Calculate return
    if res.is_a?(Net::HTTPSuccess)
      log("Email sent successfully!", "debug")
      return { "message_id" => "graph-#{Time.now.to_i}" }  # Add return value
    else
      log("Failed to send email: #{res.code} #{res.body}", "error")
      @error_message += "\nGraph API Error: #{res.code} #{res.body}"
      return { "message_id" => nil }  # Add return value
    end

  end

  def extract_and_embed_images_graph(payload, html_body)
    log("Extracting inline images from HTML", "debug")
    
    # Find all cid: references in the HTML
    html_body.scan(/"cid:(.*?)"/) do |match|
      url = match[0]
      log("Found inline image reference: #{url}", "debug")
      
      begin
        # Download the image
        response = RestClient.get(url)
        file_content = response.body
        base64_content = Base64.strict_encode64(file_content)
        
        # Extract filename from URL
        uri = URI.parse(url)
        filename = File.basename(uri.path)
        content_id = filename
        
        # Determine content type
        content_type = response.headers[:content_type] || determine_content_type(filename)
        
        # Add as inline attachment to payload
        payload[:message][:attachments] << {
          "@odata.type" => "#microsoft.graph.fileAttachment",
          "name" => filename,
          "contentType" => content_type,
          "contentBytes" => base64_content,
          "contentId" => content_id,
          "isInline" => true
        }
        
        log("Embedded inline image: #{filename} as #{content_id}", "debug")
        
        # Update the HTML to reference the content ID
        payload[:message][:body][:content].gsub!("cid:#{url}", "cid:#{content_id}")
        
      rescue Exception => e
        log("Error embedding inline image #{url}: #{e.message}", "error")
      end
    end
    
    return payload
  end
  def embed_images(email_details,mail)
    # Initialize a hash of image links to embeded values
    embedded_images = {}

    # Iterate over the body and embed necessary images
    email_details[:htmlbody].scan(/"cid:(.*?)"/) do |match|
      # The match variable is an array of Regex groups (specified with
      # parentheses); in this case the first match is the url
      url = match.first
      # Unless we have already embedded this url
      unless embedded_images.has_key?(url)
        cid = embed_url(mail,url)
        embedded_images[url] = cid
      end
    end

    # Replace the image URLs with their embedded values
    embedded_images.each do |url, cid|
      email_details[:htmlbody].gsub!(url, cid)
    end

    mail.html_part do
      content_type "text/html; charset=UTF-8"
      body "#{email_details[:htmlbody]}"
    end
    return mail
  end

  def generate_payload(email_data)
    message = {
      message: {
        subject: email_data[:subject],
        body: {
          contentType: "HTML",
          content: email_data[:htmlbody]
        },
        toRecipients: email_data[:to].to_s.split(',').map { |email| { emailAddress: { address: email.strip } } },
        attachments: []
      },
      saveToSentItems: true
    }
    # Add CC recipients if provided
    unless email_data[:cc].nil? || email_data[:cc].empty?
      message[:message][:ccRecipients] = email_data[:cc].split(',').map { |email| { emailAddress: { address: email.strip } } }
    end    
    # Add BCC recipients if provided
    unless email_data[:bcc].nil? || email_data[:bcc].empty?
      message[:message][:bccRecipients] = email_data[:bcc].split(',').map { |email| { emailAddress: { address: email.strip } } }
    end
    return message
  end

  ##########################################################################
  ####            Apply Attachments for Microsoft Graph API            ####
  ##########################################################################
  def apply_attachments_graph(payload, attachmentList)
    if @submission_id.nil? || @submission_id.empty?
      log("No submission ID provided for attachments", "debug")
      return payload
    end

    if attachmentList.nil? || attachmentList.empty?
      log("No attachment list provided", "debug")
      return payload
    end

    puts "Applying attachments for Graph API" if @debug_logging_enabled

    # Submission API Route including Values
    submission_api_route = @api_server +
                            "/app/api/v1/submissions/" +
                            URI.escape(@submission_id) +
                            "/?include=values"
    
    log("Getting submission from: #{submission_api_route}", "debug")
    
    begin
      # Retrieve the Submission Values
      submission_result = RestClient::Resource.new(
        submission_api_route,
        user: @api_username,
        password: @api_password
      ).get

      log("Retrieved submission successfully", "debug")
      
      # If the submission exists
      unless submission_result.nil?
        submission = JSON.parse(submission_result)["submission"]
        
        # Find all attachment field references in the attachmentList string
        attachmentList.scan(/\$\{attachment\('(.*?)'\)\}/) do |match|
          field_name = match[0]
          field_value = submission["values"][field_name]
          
          log("Processing attachment field: #{field_name}", "debug")
          
          # If the attachment field value exists
          unless field_value.nil?
            # Attachment field values are stored as arrays, one map for each file attachment
            field_value.each_index do |index|
              file_info = field_value[index]
              file_name = file_info['name']
              
              log("Processing file: #{file_name}", "debug")
              
              # API route to get the generated attachment download link from Kinetic Request CE.
              attachment_download_api_route = @api_server +
                '/app/api/v1' +
                '/submissions/' + URI.escape(@submission_id) +
                '/files/' + URI.escape(field_name) +
                '/' + index.to_s +
                '/' + URI.escape(file_name) +
                '/url'
              
              log("Getting attachment URL from: #{attachment_download_api_route}", "debug")
              
              attachment_download_result = RestClient::Resource.new(
                attachment_download_api_route,
                user: @api_username,
                password: @api_password
              ).get

              unless attachment_download_result.nil?
                # Get the filehub url to download the file
                file_url = JSON.parse(attachment_download_result)['url']
                log("Downloading file from: #{file_url}", "debug")

                # Determine if using legacy or modern URL format
                params = CGI.parse(URI(file_url).query || "")
                is_legacy = params.has_key?('signature')
                log("Using #{is_legacy ? 'legacy' : 'modern'} url", "debug")

                # Download the file content
                file_content = if is_legacy
                  RestClient.get(file_url).body
                else
                  RestClient::Resource.new(
                    file_url,
                    user: @api_username,
                    password: @api_password
                  ).get.body
                end

                # Encode to base64 for Graph API
                base64_content = Base64.strict_encode64(file_content)
                
                # Determine content type from file extension if not provided
                content_type = file_info['contentType'] || determine_content_type(file_name)
                
                # Add attachment to the payload
                payload[:message][:attachments] << {
                  "@odata.type" => "#microsoft.graph.fileAttachment",
                  "name" => file_name,
                  "contentType" => content_type,
                  "contentBytes" => base64_content,
                  "isInline" => false
                }
                
                log("Added attachment: #{file_name} (#{content_type})", "debug")
              end
            end
          else
            log("No value found for attachment field: #{field_name}", "debug")
          end
        end
      end
    rescue RestClient::Exception => e
      error_msg = "Error retrieving attachments: #{e.message}"
      log(error_msg, "error")
      @error_message += "\n#{error_msg}"
      
      if @error_handling == "Raise Error"
        raise
      end
    rescue Exception => e
      error_msg = "Unexpected error applying attachments: #{e.class.name} - #{e.message}"
      log(error_msg, "error")
      @error_message += "\n#{error_msg}"
      
      if @error_handling == "Raise Error"
        raise
      end
    end
    
    return payload
  end

  ##########################################################################
  ####              Helper: Determine Content Type from Filename        ####
  ##########################################################################
  def determine_content_type(filename)
    extension = File.extname(filename).downcase
    
    content_types = {
      '.pdf' => 'application/pdf',
      '.doc' => 'application/msword',
      '.docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xls' => 'application/vnd.ms-excel',
      '.xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.ppt' => 'application/vnd.ms-powerpoint',
      '.pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      '.txt' => 'text/plain',
      '.csv' => 'text/csv',
      '.jpg' => 'image/jpeg',
      '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.gif' => 'image/gif',
      '.bmp' => 'image/bmp',
      '.zip' => 'application/zip',
      '.rar' => 'application/x-rar-compressed',
      '.7z' => 'application/x-7z-compressed',
      '.json' => 'application/json',
      '.xml' => 'application/xml',
      '.html' => 'text/html',
      '.htm' => 'text/html'
    }
    
    content_types[extension] || 'application/octet-stream'
  end
end
