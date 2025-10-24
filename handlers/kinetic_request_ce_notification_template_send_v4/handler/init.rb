# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), "dependencies"))

class KineticRequestCeNotificationTemplateSendV4
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
    @smtp_server        =   @info_values['smtp_server']
    @smtp_port          =   @info_values['smtp_port'] || '25'
    @smtp_tls           =   @info_values['smtp_tls'].downcase == 'true'
    @smtp_tls_method    =   "STARTTLS"
    @smtp_tls_method    =   "TLS" if @info_values['smtp_tls_method'].downcase == 'tls'
    @smtp_username      =   @info_values['smtp_username']
    @smtp_password      =   @info_values['smtp_password']
    @smtp_from          =   @info_values['smtp_from_address']
    @smtp_auth_type     =   @info_values['smtp_auth_type']
    @smtp_open_timeout  =   "5"
    @smtp_open_timeout  =   @info_values['smtp_open_timeout'] if !@info_values['smtp_open_timeout'].to_s.empty? && @info_values['smtp_open_timeout'].to_i > 0
    @api_username       =   URI.encode(@info_values['api_username'])
    @api_password       =   @info_values['api_password']
    @kapp_slug          =   @info_values['kapp_slug']
    @form_slug          =   @info_values['form_slug']

    # Determine if debug logging is enabled
    @debug_logging_enabled = @info_values["enable_debug_logging"] == 'Yes'
    puts("Logging enabled.") if @debug_logging_enabled

    @error_handling   = @parameters["error_handling"]

    # Create placeholder variables used throughout the handler
    @snippets               = []
    @snippet_re             = /\$\{snippet\(\'(.*?)\'\)}/
    @recipient_json         = {}
    @message                = {'email' => nil, 'subject' => nil, 'html' => nil, 'text' => nil}
    @replace_values         = JSON.parse(@parameters['replacement_values'])
    @replace_fields         = ['Subject', 'HTML Content', 'Text Content']
    @date_format_json       = {}
    @error_message          = ''
    @template_name          = @parameters['notification_template_name']
    @submission_id          = @parameters['submission_id']
    @template_submission_id = nil
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

    # Run replacements again.
    # if any of the replacements themselves included additional snippets to add
    # This allows sections of the email to by dynamically added via replacements.
    # And since snippets can have replacements, reapply those as well.
    template_to_use = replacesnippetsInRecord(template_to_use)

    # Replace Content in Subject, HTML Body, Text Body if a Template was found
    template_to_use["Subject"] = apply_replacements(template_to_use["Subject"])
    template_to_use["HTML Content"] = apply_replacements(template_to_use["HTML Content"])
    template_to_use["Text Content"] = apply_replacements(template_to_use["Text Content"])

    ################################################
    ##  SEND EMAIL AND CREATE NOTIFICATION IN CE  ##
    ################################################

    # Check to make sure a valid message template was found
    if !template_to_use.nil?

      # If the User has an email address and want to receive notifications
      email_results = {}
      if (!@recipient_json["smtpaddress"].to_s.empty? || !@recipient_json["smtpaddress_cc"].to_s.empty? || !@recipient_json["smtpaddress_bcc"].to_s.empty?) && @recipient_json["email notifications"].to_s.downcase != 'no'
        email_results = sendEmailMessage(template_to_use)
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
    #route =  "#{@api_server}/app/api/v1/datastore/forms/notification-data/submissions" +
    route =  "#{@api_server}/app/api/v1/kapps/#{@kapp_slug}/forms/#{@form_slug}/submissions" +
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
        @template_submission_id = records[0]['id']
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
      @template_submission_id = closestMatch
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
      if !value.nil? && !value.is_a?(Array)
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

  # This method is used to add attachments from a specific submission, as well as from the tempalate itself
  def apply_attachments(mail, attachmentList, submission_id)
    #if @submission_id.nil? || @submission_id.empty?
    if submission_id.nil? || submission_id.empty?
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
                            #URI.escape(@submission_id) +
                            URI.escape(submission_id) +
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
            #'/submissions/' + URI.escape(@submission_id) +
            '/submissions/' + URI.escape(submission_id) +
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

              puts "Downloading file to memory" if @enable_debug_logging
              mail.attachments[file_info['name']] = RestClient::Resource.new(
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
  def sendEmailMessage(template_to_use)
    puts "Sending Email Message to User" if @debug_logging_enabled
    begin

      # Create SMTP Defaults hash
      smtp_defaults = {
        :address              => @smtp_server,
        :port                 => @smtp_port,
        :authentication       => @smtp_auth_type,
        :open_timeout         => @smtp_open_timeout.to_i
      }
      smtp_defaults[:enable_starttls_auto] = @smtp_tls  if @smtp_tls_method != "TLS"
      smtp_defaults[:tls] =  @smtp_tls  if @smtp_tls_method == "TLS"

      puts "#{smtp_defaults}" if @debug_logging_enabled

      # Unless there was not a user specified
      unless @smtp_username.nil? || @smtp_username.empty?
        # Set the email authentication
        smtp_defaults[:user_name] = @smtp_username
        smtp_defaults[:password]  = @smtp_password
      end

      Mail.defaults do
        delivery_method :smtp, smtp_defaults
      end

      # Send out Message VIA SMTP
      to           = @recipient_json["smtpaddress"]["to"]
      cc           = @recipient_json["smtpaddress"]["cc"]
      bcc          = @recipient_json["smtpaddress"]["bcc"]
      from         = @smtp_from
      display_name = @smtp_from
      subject      = template_to_use["Subject"]
      htmlbody     = template_to_use["HTML Content"]
      textbody     = template_to_use["Text Content"]

      mail = Mail.new do
        from          "#{display_name} <#{from}>"
        to            "#{to}"
        cc            "#{cc}"
        bcc           "#{bcc}"
        subject       "#{subject}"

        text_part do
          body "#{textbody}"
        end
      end

      # Embed linked images into the html body if present
      unless htmlbody.nil? || htmlbody.empty?
        # Initialize a hash of image links to embeded values
        embedded_images = {}

        # Iterate over the body and embed necessary images
        htmlbody.scan(/"cid:(.*)"/) do |match|
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
          htmlbody.gsub!(url, cid)
        end

        mail.html_part do
          content_type "text/html; charset=UTF-8"
          body "#{htmlbody}"
        end
      end

      if !template_to_use["Attachments"].nil?
        #mail = apply_attachments(mail, template_to_use["Attachments"])
        mail = apply_attachments(mail, template_to_use["Attachments"], @submission_id)
      end
      if !template_to_use["Template Attachments"].nil? && !template_to_use["Template Attachments"].empty?
        mail = apply_attachments(mail, template_to_use["Attachments"], @template_submission_id)
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
        @error_message = @error_message + send_error
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
end
