# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), "dependencies"))
require 'logger'

class KineticRequestCeSubmissionDbBulkUpsertV1

  @@activeThread = java.util.concurrent.atomic.AtomicReference.new()
  @@made_definition_tables = java.util.concurrent.atomic.AtomicReference.new()
  @@kapp_form_table_cache = {}
  @@kapp_table_cache = []

  # Constants
  # List of text/char columns and their max lengths
  @@DB_COLUMN_SIZE_LIMITS = {
    :anonymous    => 36,
    :closedBy     => 255,
    :columnName   => 128,
    :coreState    => 10,
    :createdBy    => 255,
    :fieldKey     => 255,
    :formField    => 4000,
    :formName     => 255,
    :formSlug     => 255,
    :id           => 36,
    :kappSlug     => 255,
    :parentId     => 36,
    :originId     => 36,
    :submittedBy  => 255,
    :tableName    => 128,
    :type         => 255,
    :updatedBy    => 255
  }
  @@DEFAULT_SUBMISSION_QUERY_PAGE_SIZE = 100
  # Hash of kapp fields organized by kapp slug
  @@KAPP_FIELDS = {}
  @@SUBMISSION_INCLUDES = [
    "details",
    "form",
    "form.details",
    "form.versionId",
    "form.fields.details",
    "type",
    "form.kapp",
    "values"
  ].join(",")

#######################################################################################################
#
# initialize
#
# Prepare for execution by building Hash objects for necessary values and
# validating the present state.  This method sets the following instance
# variables when executed through the Kinetic Task engine:
# * @input_document - A REXML::Document object that represents the input Xml.
# * @info_values - A Hash of info names to info values.
# * @parameters - A Hash of parameter names to parameter values.
#
# This method sets the following instance variables when executed from a batch driver ruby script:
# *
# *
#
# This method always sets the following instance variables:
# * @table_temp_prefix - The prefix for a temporary table in the database.
#
# This is a required method that is automatically called by the Kinetic Task
# Engine.
#
# ==== Parameters
# * +input+ - The String of Xml that was built by evaluating the node.xml
#   handler template.
#
#######################################################################################################

  def initialize(input)

    @info_values = {}

    @parameters = {}
    @table_temp_prefix = "tmp_"

    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    # Retrieve all of the handler info values and store them in a hash variable named @info_values.
    REXML::XPath.each(@input_document, "/handler/infos/info") do |item|
      @info_values[item.attributes["name"]] = item.text.to_s.strip
    end

    # Retrieve all of the handler parameters and store them in a hash variable named @parameters.
    REXML::XPath.each(@input_document, "/handler/parameters/parameter") do |item|
      @parameters[item.attributes["name"]] = item.text.to_s.strip
    end

    @enable_debug_logging = ["yes", "true"].include?(@info_values['enable_debug_logging'].to_s.strip.downcase)
    @enable_trace_logging = ["yes", "true"].include?(@info_values['enable_trace_logging'].to_s.strip.downcase)

    # Configuration for datastore kapp table handling (default: skip datastore kapp tables)
    @skip_datastore_kapp_table = @parameters['skip_datastore_kapp_table'].to_s.strip.downcase != "false"

    puts "Parameters: #{@parameters.inspect}" if @enable_debug_logging

    host            = @info_values["host"]
    port            = @info_values["port"]
    database_name   = @info_values["database_name"]
    user            = @info_values["user"]
    password        = @info_values["password"]
    jdbc_url_opts   = @info_values["jdbc_url_opts"].to_s.strip

    @api_username    = URI.encode(@info_values["api_username"])
    @api_password    = @info_values["api_password"]

    # get space slug from parameters and if not specified there, then from the info value
    space_slug = @parameters["space_slug"].empty? ? @info_values["space_slug"] : @parameters["space_slug"]

    if @info_values['api_server'].to_s.empty? == false then
      if @info_values['api_server'].include?("${space}")
        @api_server = @info_values['api_server'].gsub("${space}", space_slug).chomp("/")
      elsif !space_slug.to_s.empty?
        @api_server = @info_values['api_server'].chomp("/")+"/"+space_slug
      else
        @api_server = @info_values['api_server'].chomp("/")
      end
    end

    max_connections = 1
    if @info_values['max_connections'].to_s =~ /\A[1-9]\d*\z/ then
      max_connections = @info_values["max_connections"].to_i
    end

    pool_timeout = 10
    if @info_values['pool_timeout'].to_s =~ /\A[1-9]\d*\z/ then
      pool_timeout = @info_values["pool_timeout"].to_i
    end

    @using_oracle = false
    Sequel.default_timezone = :utc

    # Attempt to connect to the database
    if @info_values["jdbc_database_id"].downcase == "sqlserver"
      jdbc_url_opts.concat(";") if jdbc_url_opts.empty? == false && jdbc_url_opts[-1] != ";"
      @db = Sequel.connect("jdbc:#{@info_values["jdbc_database_id"]}://#{host}:#{port};#{jdbc_url_opts}database=#{database_name};user=#{user};password=#{password}", :max_connections => max_connections, :pool_timeout => pool_timeout)
      @db.extension :identifier_mangling
      @db.identifier_input_method = nil
      @db.identifier_output_method = nil
      @max_db_identifier_size = 128
      @table_temp_prefix.prepend("#")
    elsif @info_values["jdbc_database_id"].downcase == "oracle"
      @db = Sequel.connect("jdbc:#{@info_values["jdbc_database_id"]}:thin:#{user}/#{password}@#{host}:#{port}:#{database_name}", :max_connections => max_connections, :pool_timeout => pool_timeout)
      @db.extension :identifier_mangling
      @db.identifier_input_method = nil
      @db.identifier_output_method = nil
      @max_db_identifier_size = 30
      @using_oracle = true
    else
      jdbc_url_opts.concat("&") if jdbc_url_opts.empty? == false && jdbc_url_opts[-1] != "&"
      @max_db_identifier_size = 64 if @info_values["jdbc_database_id"].downcase == "postgresql"
      @db = Sequel.connect("jdbc:#{@info_values["jdbc_database_id"]}://#{host}:#{port}/#{database_name}?#{jdbc_url_opts}user=#{user}&password=#{password}", :max_connections => max_connections, :pool_timeout => pool_timeout)
    end

    # Output SQL statements if the 'trace' level info parameter is set to true.
    @db.sql_log_level = :debug if @enable_trace_logging
    @db.logger = Logger.new($stdout) if @enable_trace_logging

    #Set max db identifier if info value is set to a valid positive integer.
    @max_db_identifier_size = @info_values["database_identifier_size"].strip.to_i if @info_values["database_identifier_size"].to_s.strip =~ /\A[1-9]\d*\z/
    #Decrement by 1 - used for string position truncating.
    @max_db_identifier_size -= 1

    if (!@@made_definition_tables.get()) then
      generate_table_def_table()
      generate_column_def_table()
      @@made_definition_tables.set(true)
    end

  end

#######################################################################################################
#
# execute
#
# The execute method gets called by the task engine when the handler's node is processed. It is
# responsible for performing whatever action the name indicates.
# If it returns a result, it will be in a special XML format that the task engine expects. These
# results will then be available to subsequent tasks in the process.
#
#######################################################################################################
  def execute

    #HOTFIX - Check/update column_definitions if previous value (8) for fieldKey
    #If SQLServer or postgresql
    begin
      fieldKeySize = check_field_size('column_definitions', 'fieldKey')
      if fieldKeySize.to_i == 8
        alter_column_type_size('column_definitions', 'fieldKey', 'varchar', @@DB_COLUMN_SIZE_LIMITS[:fieldKey])
      end
    rescue
    end
    #If Oracle - Above may work, untested


    # Get kapp fields and add them to the kapp_fields hash
    kapp_fields_result = get_kapp_fields({
      :api_server => @api_server,
      :kapp_slug => @parameters['specific_kapp_slug'],
      :api_username => @api_username,
      :api_password => @api_password
    })
    @@KAPP_FIELDS.merge!(kapp_fields_result)
    # Update the kapp table with new kapp fields
    # NOTE: Commenting out premature kapp table updates - these happen later in generate_submissions_schemas
    # if @parameters['specific_kapp_slug'].to_s.strip.empty?
    #   # Update tables for all kapps in @@KAPP_FIELDS
    #   @@KAPP_FIELDS.keys.each do |kapp_slug|
    #     update_kapp_table_columns({
    #       :kapp_slug => kapp_slug
    #     })
    #   end
    # else
    #   # Update table for specific kapp
    #   update_kapp_table_columns({
    #     :kapp_slug => @parameters['specific_kapp_slug']
    #   })
    # end

    # Initialize a thread to do the work
    thread = java.lang.Thread.new do
      begin
        if @parameters['specific_form_slugs'].to_s.strip.empty? == false && @parameters['specific_kapp_slug'].to_s.strip.empty? == false then
          puts "Starting specific forms submission streaming" if @enable_debug_logging
          submission_upsert_start = Time.now
          count = stream_form_submissions()
          submission_upsert_end = Time.now
          puts "Successfully processed \"#{count}\" submissions between: #{@parameters['updatedat_startdate']} and #{@parameters['updatedat_enddate']} within #{(submission_upsert_end - submission_upsert_start) * 1000} ms"
          complete_deferral("Success", "Successfully processed \"#{count}\" submissions between: #{@parameters['updatedat_startdate']} and #{@parameters['updatedat_enddate']} within #{(submission_upsert_end - submission_upsert_start) * 1000} ms") unless @parameters['deferral_token'].empty?;
        else
          puts "Starting kapp submission streaming" if @enable_debug_logging
          submission_upsert_start = Time.now
          count = stream_kapp_submissions()
          submission_upsert_end = Time.now
          puts "Successfully processed \"#{count}\" submissions between: #{@parameters['updatedat_startdate']} and #{@parameters['updatedat_enddate']} within #{(submission_upsert_end - submission_upsert_start) * 1000} ms"
          complete_deferral("Success", "Successfully processed \"#{count}\" submissions between: #{@parameters['updatedat_startdate']} and #{@parameters['updatedat_enddate']} within #{(submission_upsert_end - submission_upsert_start) * 1000} ms") unless @parameters['deferral_token'].empty?;
        end
      rescue Exception => e
        puts "ERROR: #{e.inspect}\n\t#{e.backtrace.join("\n\t")}"
        complete_deferral("Failure", build_error_message(e)) unless @parameters['deferral_token'].empty?
      # Remove self from active thread reference
      ensure
        # Disconnect DB at the end
        @db.disconnect
        puts "Disconnecting from database."
        @@activeThread.set(nil);
      end
    end



    if @@activeThread.compareAndSet(nil, thread) then
      begin
        puts "Starting thread."
        thread.start()
        # Join threads for running the handler using the test harness
        thread_join() if ENV['TEST_HANDLER']
        result = {"Started" => "true", "Error Message" => ""}
      rescue Exception => e
        puts "Thread ERROR: #{e.inspect}\n\t#{e.backtrace.join("\n\t")}"
      end
    else
      result = {"Started" => "false", "Error Message" => "There is already an instance of this process running."}
    end

    puts "About to return results"
    get_handler_xml_results(result)

  end

  # This is only called outside of Agent/Task for scripting.
  def thread_join
    puts ("Joining...")
    shutdownPlaceholderThread = java.lang.Thread.new
    joinedThread = @@activeThread.updateAndGet do |thread|
      thread.nil? ? shutdownPlaceholderThread : thread
    end
    joinedThread.join()
    puts ("Joined!");
  end

  def stream_form_submissions

    #limit_count  = @parameters['page_size'].to_s.match(/\d+/).nil? ? @parameters['page_size'].to_i : @@DEFAULT_SUBMISSION_QUERY_PAGE_SIZE
    page_size = @parameters['page_size'].to_i
    limit_count = (page_size > 0 && page_size <= 1000) ? page_size : @@DEFAULT_SUBMISSION_QUERY_PAGE_SIZE
    start_string = URI.encode(@parameters['updatedat_startdate'])
    end_string   = URI.encode(@parameters['updatedat_enddate'])
    query_string_parts = [
      "limit=#{limit_count}",
      "include=#{@@SUBMISSION_INCLUDES}",
      "direction=ASC",
      "orderBy=updatedAt"
    ]

    retrieved_submission_count = 0
    @parameters['specific_form_slugs'].split(",").each do |form_slug|

      more_submissions = true
      next_page_token = nil
      last_submission_id = nil
      while (more_submissions)
        q_string     = "updatedAt >= \"#{start_string}\" AND updatedAt < \"#{end_string}\""
        query_string = query_string_parts.join("&")
        query_string += "&q=#{q_string}"

        # API route to get submissions in a kapp
        api_route = "#{@api_server}/app/api/v1/kapps/#{@parameters['specific_kapp_slug']}/forms/#{form_slug}/submissions?#{query_string}"

        #if next_page_token.nil? == false then
        #  api_route += "&pageToken=#{next_page_token}"
        #end

        puts "Kinetic Core Submission API URL: #{api_route}" if @enable_debug_logging
        puts "Retrieving #{@parameters['specific_kapp_slug']}/#{form_slug} form submissions with page token: #{next_page_token}" if @enable_debug_logging

        read_start_time = Time.now
        resource = RestClient::Resource.new(api_route, { :user => @api_username, :password => @api_password })
        # Force UTF-8 encoding for windows. Assuming 8 bit signed (c*)
        response = resource.get.bytes.pack("c*").force_encoding("UTF-8")
        read_end_time = Time.now

        #current_page_token = next_page_token
        current_start_string = start_string
        json_response = JSON.parse(response)
        #next_page_token = json_response['nextPageToken']
        #start_string = json_response['submissions'].last['updatedAt']
        total_submissions = json_response['submissions'].size
        puts "Retrieved #{total_submissions} #{@parameters['specific_kapp_slug']}/#{form_slug} form submissions in #{(read_end_time - read_start_time) * 1000} ms [possibly including one duplicate]" if @enable_debug_logging

        #retrieved_submission_count += total_submissions

        if (json_response['submissions'].size > 0)
          submissions_to_process = json_response['submissions']

          # Remove the duplicate first record if it matches the last processed submission
          if !last_submission_id.nil? && submissions_to_process.first['id'] == last_submission_id
            submissions_to_process = submissions_to_process.drop(1)
          end

          # Only process if we have submissions after duplicate removal
          if submissions_to_process.size > 0
            write_submissions_to_db({
              :submissions => submissions_to_process
            })

            retrieved_submission_count += submissions_to_process.size

            # Update for next iteration
            last_submission = submissions_to_process.last
            start_string = last_submission['updatedAt']
            last_submission_id = last_submission['id']
          end

          # Check if we got fewer records than requested (indicating we're done)
          # Note: Use original size before duplicate removal for this check
          if json_response['submissions'].size < limit_count
            more_submissions = false
          end
        else
          more_submissions = false
        end
      end
    end

    return retrieved_submission_count

  end

  def stream_kapp_submissions

    api_route_kapps = "#{@api_server}/app/api/v1/kapps"
    puts "Kinetic Core Kapp API URL: #{api_route_kapps}" if @enable_debug_logging

    # Get all kapps in a space
    api_resource = RestClient::Resource.new(
      api_route_kapps,
      {:user => @api_username, :password => @api_password}
    )
    get_kapp_start = Time.now
    api_response = api_resource.get.body.to_s.force_encoding("UTF-8")
    all_kapps    = JSON.parse(api_response)
    total_kapps = all_kapps.has_key?('kapps') ? all_kapps['kapps'].size : 0
    puts "Retrieved #{total_kapps} kapps in #{(Time.now - get_kapp_start) * 1000} ms"

    #limit_count  = @parameters['page_size'].to_s.match(/\d+/).nil? ? @parameters['page_size'].to_i : @@DEFAULT_SUBMISSION_QUERY_PAGE_SIZE
    page_size = @parameters['page_size'].to_i
    limit_count = (page_size > 0 && page_size <= 1000) ? page_size : @@DEFAULT_SUBMISSION_QUERY_PAGE_SIZE

    retrieved_submission_count = 0
    all_kapps['kapps'].each do |kapp|
      start_string = URI.encode(@parameters['updatedat_startdate'])
      end_string   = URI.encode(@parameters['updatedat_enddate'])
      query_string_parts = [
        "limit=#{limit_count}",
        "include=#{@@SUBMISSION_INCLUDES}",
        "direction=ASC",
        "orderBy=updatedAt"
      ]

      more_submissions = true
      next_page_token = nil
      last_submission_id = nil
      while (more_submissions)

        q_string     = "updatedAt >= \"#{start_string}\" AND updatedAt < \"#{end_string}\""
        query_string = query_string_parts.join("&")
        query_string += "&q=#{q_string}"

        # API route to get submissions in a kapp
        api_route = "#{@api_server}/app/api/v1/kapps/#{kapp['slug']}/submissions?#{query_string}"

        #if next_page_token.nil? == false then
        #  api_route += "&pageToken=#{next_page_token}"
        #end

        puts "Kinetic Core Submission API URL: #{api_route}" if @enable_debug_logging
        #puts "Retrieving #{kapp['slug']} kapp submissions with page token: #{next_page_token}" if @enable_debug_logging

        read_start_time = Time.now
        resource = RestClient::Resource.new(api_route, { :user => @api_username, :password => @api_password })
        # Force UTF-8 encoding for windows. Assuming 8 bit signed (c*)
        response = resource.get.bytes.pack("c*").force_encoding("UTF-8")
        read_end_time = Time.now

        #current_page_token = next_page_token
        current_start_string = start_string
        json_response = JSON.parse(response)
        #next_page_token = json_response['nextPageToken']
        #start_string = json_response['submissions'].last['updatedAt']
        total_submissions = json_response['submissions'].size
        puts "Retrieved #{total_submissions} #{kapp['slug']} kapp submissions in #{(read_end_time - read_start_time) * 1000} ms [possibly including one duplicate]" if @enable_debug_logging

        #retrieved_submission_count += total_submissions

        #if next_page_token.nil? then
        #  more_submissions = false
        #end

        if (json_response['submissions'].size > 0)
          submissions_to_process = json_response['submissions']

          # Remove the duplicate first record if it matches the last processed submission
          if !last_submission_id.nil? && submissions_to_process.first['id'] == last_submission_id
            submissions_to_process = submissions_to_process.drop(1)
          end

          # Only process if we have submissions after duplicate removal
          if submissions_to_process.size > 0
            write_submissions_to_db({
              :submissions => submissions_to_process
            })

            retrieved_submission_count += submissions_to_process.size

            # Update for next iteration
            last_submission = submissions_to_process.last
            start_string = last_submission['updatedAt']
            last_submission_id = last_submission['id']
          end

          # Check if we got fewer records than requested (indicating we're done)
          # Note: Use original size before duplicate removal for this check
          if json_response['submissions'].size < limit_count
            more_submissions = false
          end
        else
          more_submissions = false
        end
      end
    end

    return retrieved_submission_count

  end

  def write_submissions_to_db(args)

    # Get kapp & form slug
    submissions = args[:submissions]
    page_token = args[:page_token]

    if submissions.size == 0 then
      puts "Exiting write_submissions_to_db. No submissions to process"
    end

    puts "Submissions drivers_parameters: #{submissions.inspect}" if @enable_debug_logging

    db_column_size_limits = @@DB_COLUMN_SIZE_LIMITS
    kapp_slug = submissions.first['form']['kapp']['slug']
    kapp_fields = @@KAPP_FIELDS[kapp_slug] || []
    kapp_table_name = get_kapp_table_name(kapp_slug)

    # Check if this is a datastore kapp and we should skip kapp table processing
    is_datastore_skip = (kapp_slug == 'datastore' && @skip_datastore_kapp_table)

    if is_datastore_skip
      puts "Processing datastore submissions without kapp table (grouped by form)" if @enable_debug_logging
      write_datastore_submissions_to_db(submissions)
      return
    end

    @db.transaction(:retry_on => [Sequel::SerializationFailure]) do

      # Phase one: Analysis
      submission_ids = submissions.map {|submission| submission['id'] }
      puts "Submission ids from Core: #{submission_ids.inspect}" if @enable_debug_logging

      # Phase two: Handle metadata
      generate_submissions_schemas(submissions)

      # Phase three: Check existing submissions
      existing_submissions = @db[kapp_table_name.to_sym]
        .select(:c_id, :c_updatedAt)
        .where(:c_id => submission_ids)
        .all
        .map {|record|
          [ record[:c_id], record[:c_updatedAt] ]
        }.to_h

      puts "Existing submissions: #{existing_submissions.inspect}" if @enable_debug_logging

      # Phase four: bulk upsert submission changes
      submissions.each do | submission|
        submission_id = submission["id"]

        submission_values = submission['values']
        form_definition = submission['form']
        form_slug = submission['form']['slug']
        kapp_slug = submission['form']['kapp']['slug']
        kapp_table_name = get_kapp_table_name(kapp_slug)

        # Get table names
        form_table_name   = get_form_table_name(kapp_slug, form_slug)
        unlimited_column_names_by_field, limited_column_names_by_field = get_column_names(submission_values)

        originId = nil
        parentId = nil
        if (submission['origin'].nil? == false && submission['origin'].has_key?('id')) then
          originId = submission['origin']['id']
        end
        if (submission['parent'].nil? == false && submission['parent'].has_key?('id')) then
          parentId = submission['parent']['id']
        end

        ##############################
        #  UPSERT KAPP RECORD
        ##############################
        ce_submission = {
          "c_id" => submission['id'],
          "c_formSlug" => form_slug,
          "c_anonymous" => submission['sessionToken'],
          "c_closedBy" => submission['closedBy'],
          "c_coreState" => submission['coreState'],
          "c_createdBy" => submission['createdBy'],
          "c_originId" => originId,
          "c_parentId" => parentId,
          "c_submittedBy" => submission['submittedBy'],
          "c_updatedBy" => submission['updatedBy'],
          "c_type" => submission['type'],
        }
        kapp_fields.each do |field|
          unlimited_field = get_field_column_name(:unlimited => true, :field => field)
          limited_field = get_field_column_name(:unlimited => false, :field => field)
          limited_value = submission['values'][field].nil? ? nil : submission['values'][field][0..db_column_size_limits[:formField] - 1]
          ce_submission[unlimited_field] = submission['values'][field]
          ce_submission[limited_field] = limited_value
        end

        #only set the datetime values if they're not null, and set them as a proper datetime object.
        ["closedAt", "createdAt", "submittedAt", "updatedAt"].each do |actionTimestamp|
          ce_submission["c_#{actionTimestamp}"] = DateTime.parse(submission[actionTimestamp]) if submission[actionTimestamp].nil? == false
        end

        # value.to_s is necessary for attachment and multi-value answers which are not stored as JSON strings
        submission_values.each { |field,value|
          if kapp_fields.include? field
            #ternary: if value is nil, use nil - else use the value converted to a string.
            ce_submission[unlimited_column_names_by_field[field]] = value.nil? ? nil : value.to_s
            truncated_value = value.to_s[0,db_column_size_limits[:formField] - 1]
            ce_submission[limited_column_names_by_field[field]] = value.nil? ? nil : truncated_value
          end
        }

        # {"c_id" => value, "c_formSlug" => value} -> {"c_id" => :$c_id, "c_formSlug" => :$c_formSlug}
        submission_values_columns_map = ce_submission
          .map {|k,v|
            {k => "$#{k}".to_sym}
          }.reduce Hash.new, :merge
        # {"c_id" => value, "c_formSlug" => value} -> {:c_id => value, :c_formSlug => value}
        db_submission_values = ce_submission
          .map {|k,v|
            {k.to_sym => v}
          }.reduce Hash.new, :merge

        ##puts "#{submission["id"]} DB values for Kapp record: #{ce_submission.inspect}" if @enable_debug_logging
        ##db_submissions = @db[kapp_table_name.to_sym]

        # if the record does not exist in the database, insert it.
        if existing_submissions.has_key?(submission_id) == false then
          puts "Inserting the submission #{submission["id"]} into the kapp table #{kapp_table_name}" if @enable_debug_logging
          @db[kapp_table_name.to_sym].call(
            :insert,
            # {"c_id" => value, "c_formSlug" => value} -> {:c_id => value, :c_formSlug => value}
            db_submission_values,
            submission_values_columns_map
          )
          puts "Inserted the submission #{submission["id"]}" if @enable_debug_logging
        # else if the submission updatedAt timestamp is greater than the database updatedAt, update it
        elsif (ce_submission["c_updatedAt"].to_time > existing_submissions[submission_id])
          puts "Updating the submission #{submission["id"]} into the kapp table #{kapp_table_name}" if @enable_debug_logging
          @db[kapp_table_name.to_sym].where(
            Sequel.lit('"c_id" = ? and "c_updatedAt" < ?', submission['id'], db_submission_values[:c_updatedAt]
          )).call(
            :update,
            db_submission_values,
            submission_values_columns_map
          )
          puts "Updated the submission #{submission["id"]}." if @enable_debug_logging
        else
          puts "Ignoring submission #{submission['id']} for table #{kapp_table_name}. Submission updatedAt is not newer than existing DB record." if @enable_debug_logging
        end

        ##############################
        #  UPSERT FORM RECORD
        ##############################
        puts "Submission values: (#{submission_values.inspect})" if @enable_debug_logging

        # Once the table has been created/modified/verified, insert the submission into the table
        form_db_submission = {
          "c_id" => submission["id"],
          "c_originId" => originId,
          "c_parentId" => parentId,
          "c_anonymous" => submission['sessionToken'],
          "c_closedBy" => submission["closedBy"],
          "c_coreState" => submission["coreState"],
          "c_createdBy" => submission["createdBy"],
          "c_submittedBy" => submission["submittedBy"],
          "c_updatedBy" => submission["updatedBy"]
        }

        # only set the datetime values if they're not null, and set them as a proper datetime object.
        ["closedAt", "createdAt", "submittedAt", "updatedAt"].each do |actionTimestamp|
          form_db_submission["c_#{actionTimestamp}"] = DateTime.parse(submission[actionTimestamp]) if submission[actionTimestamp].nil? == false
        end

        # value.to_s is necessary for attachment and multi-value answers which are not stored as JSON strings
        submission_values.each { |field,value|
          #ternary: if value is nil, use nil - else use the value converted to a string.
          form_db_submission[unlimited_column_names_by_field[field]] = value.nil? ? nil : value.to_s
          truncated_value = value.to_s[0,db_column_size_limits[:formField] - 1]
          form_db_submission[limited_column_names_by_field[field]] = value.nil? ? nil : truncated_value
        }

        # {"c_id" => value, "c_formSlug" => value} -> {"c_id" => :$c_id, "c_formSlug" => :$c_formSlug}
        submission_values_columns_map = form_db_submission
          .map {|k,v|
            {k => "$#{k}".to_sym}
          }.reduce Hash.new, :merge
        # {"c_id" => value, "c_formSlug" => value} -> {:c_id => value, :c_formSlug => value}
        db_submission_values = form_db_submission
          .map {|k,v|
            {k.to_sym => v}
          }.reduce Hash.new, :merge

        puts "#{submission["id"]} DB values: #{form_db_submission.inspect}" if @enable_debug_logging
        db_submissions = @db[form_table_name.to_sym]

        # if the record does not exist in the database, insert it.
        if existing_submissions.has_key?(submission_id) == false then
          puts "Inserting the submission #{submission["id"]} into the form table #{form_table_name}" if @enable_debug_logging
          submission_database_id = db_submissions.call(
            :insert,
            db_submission_values,
            submission_values_columns_map
          )
          puts "Inserted the submission #{submission["id"]}" if @enable_debug_logging

        # else if the submission updatedAt timestamp is greater than the database updatedAt, update it
        elsif (form_db_submission["c_updatedAt"].to_time > existing_submissions[submission_id])
          puts "Updating the submission #{submission["id"]} into the form table #{form_table_name}" if @enable_debug_logging
          submission_update_count = db_submissions.where(
            Sequel.lit('"c_id" = ? and "c_updatedAt" < ?', submission['id'], db_submission_values[:c_updatedAt])
          )
            .call(
              :update,
              db_submission_values,
              submission_values_columns_map
            ) unless @info_values['ignore_updates']
          puts "Updated #{submission_update_count} row(s) - #{submission["id"]}." if @enable_debug_logging
        else
          puts "Ignoring submission #{submission['id']} for form #{form_table_name}. Submission updatedAt is not newer than existing DB record." if @enable_debug_logging
        end
      #end submission looping
      end
    #end database transaction
    end
  #end method
  end

##########################################################################################################
#
# write_datastore_submissions_to_db
#
# Process datastore submissions without kapp table, grouped by form for efficient querying
#
##########################################################################################################

  def write_datastore_submissions_to_db(submissions)

    # Group submissions by form_slug for sequential processing
    submissions_by_form = submissions.group_by { |submission| submission['form']['slug'] }

    puts "Processing #{submissions_by_form.keys.size} forms in datastore: #{submissions_by_form.keys.sort}" if @enable_debug_logging

    # Process each form's submissions separately
    submissions_by_form.keys.sort.each do |form_slug|
      form_submissions = submissions_by_form[form_slug]
      kapp_slug = form_submissions.first['form']['kapp']['slug'] # Should be 'datastore'

      puts "Processing #{form_submissions.size} submissions for datastore form: #{form_slug}" if @enable_debug_logging

      @db.transaction(:retry_on => [Sequel::SerializationFailure]) do

        # Phase one: Schema generation for this form
        generate_submissions_schemas(form_submissions)

        # Phase two: Get existing submissions from FORM table (not kapp table)
        form_table_name = get_form_table_name(kapp_slug, form_slug)
        submission_ids = form_submissions.map {|submission| submission['id'] }

        existing_submissions = @db[form_table_name.to_sym]
          .select(:c_id, :c_updatedAt)
          .where(:c_id => submission_ids)
          .all
          .map {|record|
            [ record[:c_id], record[:c_updatedAt] ]
          }.to_h

        puts "Found #{existing_submissions.size} existing submissions in form table #{form_table_name}" if @enable_debug_logging

        # Phase three: Process each submission (only form table, no kapp table)
        form_submissions.each do |submission|
          submission_id = submission["id"]
          submission_values = submission['values']

          # Get table names and column mappings
          unlimited_column_names_by_field, limited_column_names_by_field = get_column_names(submission_values)

          # Build form submission record
          form_db_submission = build_submission_record(submission, unlimited_column_names_by_field, limited_column_names_by_field)

          # Convert to database format
          submission_values_columns_map = form_db_submission
            .map {|k,v|
              {k => "$#{k}".to_sym}
            }.reduce Hash.new, :merge
          db_submission_values = form_db_submission
            .map {|k,v|
              {k.to_sym => v}
            }.reduce Hash.new, :merge

          # Insert or update in form table only
          if existing_submissions.has_key?(submission_id) == false then
            puts "Inserting datastore submission #{submission_id} into form table #{form_table_name}" if @enable_debug_logging
            @db[form_table_name.to_sym].call(
              :insert,
              db_submission_values,
              submission_values_columns_map
            )
            puts "Inserted datastore submission #{submission_id}" if @enable_debug_logging
          elsif (form_db_submission["c_updatedAt"].to_time > existing_submissions[submission_id])
            puts "Updating datastore submission #{submission_id} in form table #{form_table_name}" if @enable_debug_logging
            @db[form_table_name.to_sym].where(
              Sequel.lit('"c_id" = ? and "c_updatedAt" < ?', submission['id'], db_submission_values[:c_updatedAt])
            ).call(
              :update,
              db_submission_values,
              submission_values_columns_map
            ) unless @info_values['ignore_updates']
            puts "Updated datastore submission #{submission_id}" if @enable_debug_logging
          else
            puts "Ignoring datastore submission #{submission_id}. Not newer than existing record." if @enable_debug_logging
          end
        end
      end
    end
  end

  # Helper method to build submission record (extracted from main method)
  def build_submission_record(submission, unlimited_column_names_by_field, limited_column_names_by_field)
    submission_values = submission['values']
    form_definition = submission['form']

    originId = nil
    parentId = nil
    if (submission['origin'].nil? == false && submission['origin'].has_key?('id')) then
      originId = submission['origin']['id']
    end
    if (submission['parent'].nil? == false && submission['parent'].has_key?('id')) then
      parentId = submission['parent']['id']
    end

    # Build the standard submission record
    db_submission = {
      "c_id" => submission["id"],
      "c_originId" => originId,
      "c_parentId" => parentId,
      "c_anonymous" => submission['sessionToken'],
      "c_closedBy" => submission["closedBy"],
      "c_coreState" => submission["coreState"],
      "c_createdBy" => submission["createdBy"],
      "c_submittedBy" => submission["submittedBy"],
      "c_updatedBy" => submission["updatedBy"]
    }

    #only set the datetime values if they're not null, and set them as a proper datetime object.
    ["closedAt", "createdAt", "submittedAt", "updatedAt"].each do |actionTimestamp|
      db_submission["c_#{actionTimestamp}"] = DateTime.parse(submission[actionTimestamp]) if submission[actionTimestamp].nil? == false
    end

    # Add form field values
    submission_values.each { |field,value|
      #ternary: if value is nil, use nil - else use the value converted to a string.
      db_submission[unlimited_column_names_by_field[field]] = value.nil? ? nil : value.to_s
      truncated_value = value.to_s[0,@@DB_COLUMN_SIZE_LIMITS[:formField] - 1]
      db_submission[limited_column_names_by_field[field]] = value.nil? ? nil : truncated_value
    }

    return db_submission
  end

##########################################################################################################
#
# get_field_column_name
#
# Returns a column name for a field name on a form. Handles scenarios for when a field name is loner than
# what column lengths support and prefixes the column name with a u or an l to indicate if it is an unlimited
# length column or a limited length column.
#
##########################################################################################################

  def get_field_column_name(args)
    #expected args => :unlimited, :field
    prefix = args[:unlimited] ? "u_" : "l_"
    field_id = "_#{args[:field_id]}"
    field_name = args[:field]
    column_name = "#{prefix}#{field_name}"
    checksum = "_#{Digest::CRC16.hexdigest(field_name)}"
    field_truncate_pos = @max_db_identifier_size - (prefix.size + checksum.size)
    if column_name.size > @max_db_identifier_size then
      "#{prefix}#{field_name[0,field_truncate_pos]}#{checksum}"
    else
      column_name
    end
  end

##########################################################################################################
#
# get_form_table_name
#
# Returns a form table name for a form based on kapp slug and form slug. Handles temporary tables & checks if a CRC16 checksum is necessary to append
#
##########################################################################################################

  def get_form_table_name(kapp_slug, form_slug, options = {})
    # Default to datastore for form table name...
    form_table_name = "app_#{form_slug}"
    if kapp_slug.to_s.strip.empty? == false then
      form_table_name = "#{kapp_slug}_#{form_slug}"
    end
    form_table_name.prepend(@table_temp_prefix) if options[:is_temporary]
    checksum = "_#{Digest::CRC16.hexdigest(form_table_name)}"
    truncate_pos = @max_db_identifier_size - checksum.size
    if form_table_name.size > @max_db_identifier_size then
      new_table_name = "#{form_table_name[0,truncate_pos]}#{checksum}"
    else
      new_table_name = form_table_name
    end

    puts "Form table name: #{new_table_name}" if @enable_debug_logging

    new_table_name

  end

##########################################################################################################
#
# get_kapp_table_name
#
# Returns a kapp table name for a kapp slug. Handles temporary tables & checks if a CRC16 checksum is necessary to append
#
##########################################################################################################

  def get_kapp_table_name(kapp_slug, options = {})
    kapp_table_name = "#{kapp_slug}"
    kapp_table_name.prepend(@table_temp_prefix) if options[:is_temporary]
    checksum = "_#{Digest::CRC16.hexdigest(kapp_table_name)}"
    truncate_pos = @max_db_identifier_size - checksum.size
    if kapp_table_name.size > @max_db_identifier_size then
      new_table_name = "#{kapp_table_name[0,truncate_pos]}#{checksum}"
    else
      new_table_name = kapp_table_name
    end

    puts "Kapp table name: #{new_table_name}" if @enable_debug_logging

    new_table_name

  end

##########################################################################################################
#
# generate_column_def_table
#
# generates the column definition table. This table helps map form fields to their column names in form tables.
# Useful for columns that have to use a CRC16 checksum to shorten their column name.
#
##########################################################################################################

  def generate_column_def_table()
    table_def_name = "column_definitions"
    # If the table doesn't already exist, create it
    puts "Creating column definition table (#{table_def_name}) if it doesn't exist." if @enable_debug_logging
    db_column_size_limits = @@DB_COLUMN_SIZE_LIMITS

    @db.create_table?(table_def_name.to_sym) do
      String :tableName, :size => db_column_size_limits[:tableName]
      String :kappSlug, :size => db_column_size_limits[:kappSlug]
      String :formSlug, :size => db_column_size_limits[:formSlug]
      String :fieldName, :text => true
      String :fieldKey, :size => db_column_size_limits[:fieldKey]
      String :columnName, :size => db_column_size_limits[:columnName]
      primary_key [:tableName, :columnName]
    end
  end

##########################################################################################################
#
# generate_table_def_table
#
# generates the table definition table. This table helps map forms to their table names.
# Useful for tables that have to use a CRC16 checksum to shorten their table name.
#
##########################################################################################################

  def generate_table_def_table()
    table_def_name = "table_definitions"

    # If the table doesn't already exist, create it
    puts "Creating table definition table (#{table_def_name}) if it doesn't exist." if @enable_debug_logging
    db_column_size_limits = @@DB_COLUMN_SIZE_LIMITS
    @db.create_table?(table_def_name.to_sym) do
      String :tableName, :primary_key => true, :size => db_column_size_limits[:tableName]
      String :kappSlug, :size => db_column_size_limits[:kappSlug]
      String :formSlug, :size => db_column_size_limits[:formSlug]
      String :formName, :size => db_column_size_limits[:formName]
    end
  end

##########################################################################################################
#
# insert_column_definition
#
# Insert a record into a column definition table for defining a new form field column being adding to a form table.
# This helps map a full length field name to a column name in a form table.
#
##########################################################################################################

  def insert_column_definition(args)

    submission_database_id = nil
    submission = args[:submission]
    column_name = args[:column_name]
    ce_field = args[:ce_field]
    form_table_name = args[:form_table_name]
    kapp_slug = args[:kapp_slug]
    form_slug = args[:form_slug]

    field_id_lookup = {}
    submission['form']['fields'].each do |field|
      id = field['key']
      name = field['name']
      field_id_lookup[name] = id
    end

    table_def_name = "column_definitions"

    #Table definition generation.
    # Once the table has been created/modified/verified, insert the submission into the table
    db_submission = {
      :tableName => form_table_name,
      :kappSlug => kapp_slug,
      :formSlug => form_slug,
      :fieldName => ce_field,
      :fieldKey => field_id_lookup[ce_field],
      :columnName => column_name
    }

    puts "Upserting the column definition for the column name '#{column_name}'" if @enable_debug_logging
    db_submissions = @db[table_def_name.to_sym]
    if db_submissions.select(:tableName).where(:tableName => form_table_name, :columnName => column_name).count == 0 then
      submission_database_id = db_submissions.insert(db_submission)
    else
      submission_database_id = db_submissions.where(:tableName => form_table_name, :columnName => column_name).update(db_submission) unless @info_values['ignore_updates']
    end

    submission_database_id

  end

##########################################################################################################
#
# insert_table_definition
#
# Insert a record into a table definition for defining a new table being created in the database. Includes full form name and slug.
#
##########################################################################################################

  def insert_table_definition(args)

    submission_database_id = nil
    form_definition = args[:form_definition]
    form_table_name = args[:form_table_name]
    kapp_slug = args[:kapp_slug]
    form_slug = args[:form_slug]

    table_def_name = "table_definitions"

    #Table definition generation.

    # Once the table has been created/modified/verified, insert the submission into the table
    db_submission = {
      :tableName => form_table_name,
      :kappSlug => kapp_slug,
      :formSlug => form_slug,
      :formName => form_definition['name']
    }

    puts "Upserting the table definition for the table '#{form_table_name}' into '#{table_def_name}'" if @enable_debug_logging
    db_submissions = @db[table_def_name.to_sym]
    if db_submissions.select(:tableName).where(:tableName => form_table_name).count == 0 then
      submission_database_id = db_submissions.insert(db_submission)
    else
      submission_database_id = db_submissions.where(:tableName => form_table_name).update(db_submission) unless @info_values['ignore_updates']
    end

    submission_database_id

  end

##########################################################################################################
#
# update_form_table_columns
#
# Updates the form table with new columns, based on submission values, if they do not already exist on the table.
#
##########################################################################################################

  def update_form_table_columns(args)

    submission        = args[:submission]
    kapp_slug         = args[:kapp_slug]
    form_slug         = args[:form_slug]
    submission_values = submission['values']
    canonical_form = get_canonical_form_cache_name({
      :api_server => @api_server,
      :kapp_slug => kapp_slug,
      :form_slug => form_slug
    })
    unlimited_column_names_by_field, limited_column_names_by_field = get_column_names(submission_values)

    form_table_name = get_form_table_name(kapp_slug, form_slug, {:is_temporary => args[:is_temporary]})

    # If the table exists, check to see if the submission values match up with
    # the table columns. If a column doesn't exist, add it
    form_fields_to_add = []

    columns = get_table_column_names(form_table_name.to_sym)
    columns_to_add = []
    column_to_field_name = {}

    submission_values.each do |field,value|
      sql_column_unlimited = unlimited_column_names_by_field[field]
      sql_column_limited = limited_column_names_by_field[field]
      columns_to_add.push(sql_column_unlimited) if !columns.include?(sql_column_unlimited.to_sym)
      form_fields_to_add.push(field) if !columns.include?(sql_column_unlimited.to_sym)
      columns_to_add.push(sql_column_limited) if !columns.include?(sql_column_limited.to_sym)
      column_to_field_name[sql_column_limited] = field
      column_to_field_name[sql_column_unlimited] = field
    end
    if columns_to_add.empty? == false
      puts "Adding the new columns '#{columns_to_add.join(",")}' to #{form_table_name}" if @enable_debug_logging
      @db.alter_table(form_table_name.to_sym) do
        columns_to_add.each { |sql_column| add_column(sql_column.to_sym, String, :text => true) }
      end
      columns_to_add.each { |sql_column|
        insert_column_definition({
          :form_slug => form_slug,
          :kapp_slug => kapp_slug,
          :submission => submission,
          :form_table_name => form_table_name,
          :ce_field => column_to_field_name[sql_column],
          :column_name => sql_column
        })
      }
    end

    @@kapp_form_table_cache[canonical_form] = submission['form']['versionId']
    puts "update_form_table_columns :: @@kapp_form_table_cache => #{@@kapp_form_table_cache.inspect}"

  end

##########################################################################################################
#
# update_kapp_table_columns
#
# Updates the kapp table with new columns, based on the kapp list and if they do not already exist on the table.
#
##########################################################################################################

  def update_kapp_table_columns(args)
    # Get list of columns for the kapp table
    table_columns = get_table_column_names(args[:kapp_slug].to_sym)

    # Get a list of unique kapp columns (table has a mix of metadata and kapp field columns)
    reduced_columns = table_columns.reduce([]) do |acc, column|
      column[0,2] == "l_" ? acc << column[2..-1] : acc
    end

    # Get a list of kapp fields that are not columns on the kapp table
    missing_columns = (@@KAPP_FIELDS[args[:kapp_slug]] || []) - reduced_columns

    # Get a list of limited and unlimited column names
    unlimited_column_names_by_field, limited_column_names_by_field = get_column_names(missing_columns)

    # Get a list of columns to add to the kapp table
    columns_to_add = unlimited_column_names_by_field.values.concat(limited_column_names_by_field.values)

    # Get the kapp table name
    kapp_table_name = get_kapp_table_name(args[:kapp_slug], {:is_temporary => args[:is_temporary]})

    # Add new columns to the kapp table
    if columns_to_add.empty? == false
      @db.transaction(:retry_on => [Sequel::SerializationFailure]) do
        puts "Adding the new columns '#{columns_to_add.join(",")}' to #{kapp_table_name}" if @enable_debug_logging
        # Assigning outside of the alter_table block because code inside the block is referring to a different instance and not have access to this variable.
        using_oracle = @using_oracle
        db_column_size_limits = @@DB_COLUMN_SIZE_LIMITS

        @db.alter_table(kapp_table_name.to_sym) do
          columns_to_add.each { |sql_column|
            if sql_column.start_with?("u_")
              if using_oracle then
                # TODO: test against oracle system
                add_column(sql_column.to_sym, String, :text => true, :unicode => true)
              else
                add_column(sql_column.to_sym, String, :text => true, :unicode => true)
              end
            else
              add_column(sql_column.to_sym, String, :unicode => true, :size => db_column_size_limits[:formField])
            end
          }
        end
      end
    end
  end

##########################################################################################################
#
# get_kapp_fields
#
# Get a list of kapp fields from Core
#
##########################################################################################################

  def get_kapp_fields(args)
    if args[:kapp_slug].to_s.strip.empty?
      # Get all kapps
      api_route = "#{args[:api_server]}/app/api/v1/kapps?include=fields&limit=1000"
      puts "API ROUTE: #{api_route}" if @enable_debug_logging
      resource = RestClient::Resource.new(api_route, { :user => args[:api_username], :password => args[:api_password] })
      response = resource.get

      response_json = JSON.parse(response)

      # Return hash with all kapps
      kapp_fields_by_slug = {}
      response_json["kapps"].each do |kapp|
        kapp_fields_by_slug[kapp["slug"]] = kapp["fields"].map { |field| field["name"] }
      end
      return kapp_fields_by_slug
    else
      # Get specific kapp
      api_route = "#{args[:api_server]}/app/api/v1/kapps/#{args[:kapp_slug]}?include=fields&limit=1000"
      puts "API ROUTE: #{api_route}" if @enable_debug_logging
      resource = RestClient::Resource.new(api_route, { :user => args[:api_username], :password => args[:api_password] })
      response = resource.get

      response_json = JSON.parse(response)

      # Return hash with single kapp
      kapp_slug = response_json["kapp"]["slug"]
      kapp_fields = response_json["kapp"]["fields"].map { |field| field["name"] }
      return { kapp_slug => kapp_fields }
    end
  end

##########################################################################################################
#
# generate_kapp_table
#
# Creates the kapp table if it does not already exist.
#
##########################################################################################################

  def generate_kapp_table(kapp_slug, opt_args = {})
    # If the table doesn't already exist, create it
    db_table_name = get_kapp_table_name(kapp_slug, {:is_temporary => opt_args[:is_temporary]})
    db_options = {}
    db_options[:temp] = true if opt_args[:is_temporary]
    db_options[:on_commit_preserve_rows] = true if opt_args[:is_temporary] && @info_values["jdbc_database_id"].downcase == "oracle"

    db_column_size_limits = @@DB_COLUMN_SIZE_LIMITS
    using_oracle = @using_oracle
    kapp_fields = @@KAPP_FIELDS[kapp_slug] || []
    kapp_unlimited_column_name = {}
    kapp_limited_column_name = {}
    kapp_fields.each do |field|
      kapp_unlimited_column_name[field] = get_field_column_name(:unlimited => true, :field => field)
      kapp_limited_column_name[field] = get_field_column_name(:unlimited => false, :field => field)
    end
    puts "Creating Kapp table (#{db_table_name}) if it doesn't exist."

    @db.create_table?(db_table_name.to_sym, db_options) do
      String :c_id, :primary_key => true, :size => db_column_size_limits[:id]
      String :c_originId, :size => db_column_size_limits[:originId]
      String :c_parentId, :size => db_column_size_limits[:parentId]
      String :c_formSlug, :size => db_column_size_limits[:formSlug]
      String :c_anonymous, :size => db_column_size_limits[:anonymous]
      column :c_closedAt, (using_oracle ? 'timestamp with time zone' : DateTime)
      String :c_closedBy, :size => db_column_size_limits[:closedBy], :unicode => true
      String :c_coreState, :size => db_column_size_limits[:coreState]
      column :c_createdAt, (using_oracle ? 'timestamp with time zone' : DateTime)
      String :c_createdBy, :size => db_column_size_limits[:createdBy], :unicode => true
      column :c_deletedAt, (using_oracle ? 'timestamp with time zone' : DateTime)
      column :c_submittedAt, (using_oracle ? 'timestamp with time zone' : DateTime)
      String :c_submittedBy, :size => db_column_size_limits[:submittedBy], :unicode => true
      column :c_updatedAt, (using_oracle ? 'timestamp with time zone' : DateTime)
      String :c_updatedBy, :size => db_column_size_limits[:updatedBy], :unicode => true
      String :c_type, :size => db_column_size_limits[:type]
      kapp_fields.each do |field|
        if using_oracle then
          send("column", kapp_unlimited_column_name[field], "CLOB")
        else
          send("String", kapp_unlimited_column_name[field], :text => true, :unicode => true)
        end
        send("String",kapp_limited_column_name[field], :unicode => true, :size => db_column_size_limits[:formField])
      end
    end

  end

##########################################################################################################
#
# generate_form_table
#
# Generates the form table and creates column definition records for every field on the form (for both the limited and unlimited length columns)
#
##########################################################################################################

  def generate_form_table(args)
    form_table_name = get_form_table_name(
      args[:kapp_slug],
      args[:form_slug],
      {:is_temporary => args[:is_temporary]}
    )
    canonical_form = get_canonical_form_cache_name({
      :api_server => @api_server,
      :kapp_slug => args[:kapp_slug],
      :form_slug => args[:form_slug]
    })
    submission = args[:submission]
    unlimited_column_names_by_field, limited_column_names_by_field = get_column_names(submission['values'])
    db_options = {}
    db_options[:temp]                    = true if args[:is_temporary]
    db_options[:on_commit_preserve_rows] = true if args[:is_temporary] && @info_values["jdbc_database_id"].downcase == "oracle"

    db_column_size_limits = @@DB_COLUMN_SIZE_LIMITS
    using_oracle = @using_oracle

    # If the table doesn't already exist, create it
    puts "Creating Form table (#{form_table_name}) if it doesn't exist."
    @db.create_table?(form_table_name.to_sym, db_options) do
      String :c_id, :primary_key => true, :size => db_column_size_limits[:id]
      String :c_originId, :size => db_column_size_limits[:originId]
      String :c_parentId, :size => db_column_size_limits[:parentId]
      String :c_anonymous, :size => db_column_size_limits[:anonymous]
      column :c_closedAt, (using_oracle ? 'timestamp with time zone' : DateTime)
      String :c_closedBy, :size => db_column_size_limits[:closedBy], :unicode => true
      String :c_coreState, :size => db_column_size_limits[:coreState]
      column :c_createdAt, (using_oracle ? 'timestamp with time zone' : DateTime)
      String :c_createdBy, :size => db_column_size_limits[:createdBy], :unicode => true
      column :c_deletedAt, (using_oracle ? 'timestamp with time zone' : DateTime)
      column :c_submittedAt, (using_oracle ? 'timestamp with time zone' : DateTime)
      String :c_submittedBy, :size => db_column_size_limits[:submittedBy], :unicode => true
      String :c_type, :size => db_column_size_limits[:type], :unicode => true
      column :c_updatedAt, (using_oracle ? 'timestamp with time zone' : DateTime)
      String :c_updatedBy, :size => db_column_size_limits[:updatedBy], :unicode => true
      submission['values'].each do |field,value|
        if using_oracle then
          send("column", unlimited_column_names_by_field[field].to_sym, 'CLOB')
        else
          send("String", unlimited_column_names_by_field[field].to_sym, :text => true, :unicode => true)
        end
        send("String",limited_column_names_by_field[field].to_sym, :unicode => true, :size => db_column_size_limits[:formField])
      end
    end

    submission['values'].each do |field,value|
      insert_column_definition({
        :submission => submission,
        :form_slug => args[:form_slug],
        :kapp_slug => args[:kapp_slug],
        :form_table_name => form_table_name,
        :ce_field => field,
        :column_name => unlimited_column_names_by_field[field]
      })
      insert_column_definition({
        :submission => submission,
        :form_slug => args[:form_slug],
        :kapp_slug => args[:kapp_slug],
        :form_table_name => form_table_name,
        :ce_field => field,
        :column_name => limited_column_names_by_field[field]
      })
    end

    @@kapp_form_table_cache[canonical_form] = submission['form']['versionId']
    puts "generate_form_table :: @@kapp_form_table_cache => #{@@kapp_form_table_cache.inspect}"

  end

##########################################################################################################
#
# create_or_update_form_table
#
# either creates a form table along with adding a definition entry or updates the columns in the existing table
#
##########################################################################################################

  def create_or_update_form_table(args)

    canonical_form = get_canonical_form_cache_name({
      :api_server => @api_server,
      :kapp_slug => args[:kapp_slug],
      :form_slug => args[:form_slug]
    })
    puts "Canonical form name: #{canonical_form}" if @enable_debug_logging

    if (@@kapp_form_table_cache.has_key?(canonical_form) == false)
      form_table_name = get_form_table_name(
        args[:kapp_slug],
        args[:form_slug],
        {:is_temporary => args[:is_temporary]}
      )

      if @db.table_exists?(form_table_name.to_sym) == false then
        generate_form_table({
          :kapp_slug => args[:kapp_slug],
          :form_slug => args[:form_slug],
          :submission => args[:submission],
          :is_temporary => args[:is_temporary]
        })
        insert_table_definition({
          :kapp_slug => args[:kapp_slug],
          :form_slug => args[:form_slug],
          :form_table_name => form_table_name,
          :form_definition => args[:submission]['form']
        })
      else
        update_form_table_columns({
          :submission => args[:submission],
          :kapp_slug => args[:kapp_slug],
          :form_slug => args[:form_slug],
          :is_temporary => args[:is_temporary]
        })
      end
      @@kapp_form_table_cache[canonical_form] = args[:submission]['form']['versionId']
    # If the submission has field values not in the cache, update the table columns
    elsif @@kapp_form_table_cache[canonical_form] != args[:submission]['form']['versionId']
      update_form_table_columns({
        :submission => args[:submission],
        :kapp_slug => args[:kapp_slug],
        :form_slug => args[:form_slug],
        :is_temporary => args[:is_temporary]
      })
    end

  end

##########################################################################################################
#
# get_column_names returns table column names for form fields, both limited and unlimited length.
#   NO DB interaction
#
##########################################################################################################

  def get_column_names(submission_values)
    unlimited_column_names_by_field = {}
    limited_column_names_by_field = {}
    submission_values.each do |field,value|
      unlimited_column_names_by_field[field] = get_field_column_name(:unlimited => true, :field => field)
      limited_column_names_by_field[field] = get_field_column_name(:unlimited => false, :field => field)
    end
    return unlimited_column_names_by_field, limited_column_names_by_field
  end

##########################################################################################################
#
# get_canonical_form_cache_name returns simple concatenated string, simple helper function
#
##########################################################################################################
  def get_canonical_form_cache_name(args)
    "#{args[:api_server]}_#{args[:kapp_slug]}_#{args[:form_slug]}"
  end

##########################################################################################################
#
# get_canonical_kapp_cache_name returns simple concatenated string, simple helper function
#
##########################################################################################################
  def get_canonical_kapp_cache_name(args)
    "#{args[:api_server]}_#{args[:kapp_slug]}"
  end

##########################################################################################################
#
# get_table_column_names returns an array of the columns for a specified database table.
#
##########################################################################################################

  def get_table_column_names(table)
    @db[table].columns
  end

##########################################################################################################
#
# generate_submissions_schemas
#
#   DB INTERACTION
#   Iterates through each submission to determine what form tables need to be created/updated.
#   A handler class cache is used for this purpose.
#
##########################################################################################################

  def generate_submissions_schemas(submissions)

    submissions.each do |submission|

      kapp_slug = submission['form']['kapp']['slug']
      form_slug = submission['form']['slug']
      canonical_kapp = get_canonical_kapp_cache_name({
        :api_server => @api_server,
        :kapp_slug => kapp_slug
      })

      # Skip kapp table creation for datastore if configured to do so
      should_skip_kapp_table = (kapp_slug == 'datastore' && @skip_datastore_kapp_table)

      if !@@kapp_table_cache.include?(canonical_kapp) && !should_skip_kapp_table then
        generate_kapp_table(kapp_slug)
        @@kapp_table_cache.push(canonical_kapp)
      elsif should_skip_kapp_table
        # Mark datastore as "processed" in cache to avoid repeated checks, even though no table was created
        @@kapp_table_cache.push(canonical_kapp) unless @@kapp_table_cache.include?(canonical_kapp)
        puts "Skipping kapp table creation for datastore kapp" if @enable_debug_logging
      end

      create_or_update_form_table({
        :is_temporary => false,
        :kapp_slug  => kapp_slug,
        :form_slug  => form_slug,
        :submission => submission,
      })
    end

  end

##########################################################################################################
#
# build_error_message
#
# Pretty prints an en exception.
#
##########################################################################################################
  def build_error_message(err)
    message = "There was a problem writing to the reporting database.\n"
    message += "#{err.inspect}\n#{err.backtrace.join("\n\t")}"
    return message

#    current = err
#    while (!current.nil?)
#      if (current != err) then
#        message += "Caused by "
#      end
#      message += "#{err.getClass().getName()} : #{err.getMessage()}"
#      err.getStackTrace().each do |element|
#        message += "\n    #{element.toString()}"
#      end
#      current = err.cause
#    end
#    return message
  end

##########################################################################################################
#
# complete_deferral
#
# completes the deferred node that called this handler
#
##########################################################################################################

  def complete_deferral(status, message)
    api_route = "#{@api_server}/app/components/task/app/api/v2/runs/task/#{@parameters['deferral_token']}"

    # Get all kapps in a space
    api_resource = RestClient::Resource.new(
      api_route,
      {:user => @api_username, :password => @api_password}
    )
    deferral_payload = {
      "message" => status,
      "results" => get_handler_xml_results({
        "status" => status,
        "result" => message
      })
    }.to_json
    api_response = api_resource.post(deferral_payload, :content_type => 'application/json')
      .body
      .to_s
      .force_encoding("UTF-8")

    api_response
  end

##########################################################################################################
#
# get_handler_xml_results
#
# formats all of the inputs passed to XML for Kinetic Task output
#
##########################################################################################################

  def get_handler_xml_results(args = {})
    results = "<results>"
    args.each do |key,value|
      results << %|<result name="#{escape(key.to_s)}">#{escape(value.to_s)}</result>|
    end
    results << "</results>"
    puts results if @enable_debug_logging
    return results
  end

##########################################################################################################
#
# escape
#
# This is a template method that is used to escape results values (returned in
# execute) that would cause the XML to be invalid.  This method is not
# necessary if values do not contain character that have special meaning in
# XML (&, ", <, and >), however it is a good practice to use it for all return
# variable results in case the value could include one of those characters in
# the future.  This method can be copied and reused between handlers.
#
##########################################################################################################
  def escape(string)
    # Globally replace characters based on the ESCAPE_CHARACTERS constant
    string.to_s.gsub(/[&"><]/) { |special| ESCAPE_CHARACTERS[special] } if string
  end
  # This is a ruby constant that is used by the escape method
  ESCAPE_CHARACTERS = {'&'=>'&amp;', '>'=>'&gt;', '<'=>'&lt;', '"' => '&quot;'}

##########################################################################################################
#
# check_field_size
#
# Returns size of field, created to resolve fieldKey size change in v6 upgrade
#
##########################################################################################################

  #Need to account for db_type
  def check_field_size(tableName, fieldName)
    size = nil
    @db.schema(tableName.to_sym).each {|label,columnDetails|
      if label.to_s == fieldName
        #Return size
        if @info_values["jdbc_database_id"].downcase == "postgresql"
          puts "Found Postgres" if @enable_debug_logging
          if columnDetails[:db_type].match?( /\(\d+\)/)
            size = columnDetails[:db_type][/\(.*?\)/].delete('()')
          else
            puts "Non-numeric: #{columnDetails[:db_type]}" if @enable_debug_logging
            #How to handle non-numerical fields
          end

        elsif @info_values["jdbc_database_id"].downcase == 'sqlserver'
          puts "Found sqlserver" if @enable_debug_logging
          size = columnDetails[:max_chars]
        elsif @info_values["jdbc_database_id"].downcase == 'oracle'
          #TODO
        else
          puts "Else catch" if @enable_debug_logging
          #TODO - catch case
        end
        puts "Size found: #{size}" if @enable_debug_logging
        return size
      end
    }
    puts "No size found: #{size}" if @enable_debug_logging
    return size
  end

##########################################################################################################
#
# alter_column_type_size
#
# Alters column type and or size
#
##########################################################################################################

  def alter_column_type_size(tableName, fieldName, dataType, fieldSize)
    case (@info_values["jdbc_database_id"])
    when 'postgresql'
      puts "Altering #{fieldName} column in #{@info_values["jdbc_database_id"]} - new type/size #{dataType}-#{fieldSize}" if @enable_debug_logging
      @db.alter_table(tableName.to_sym) do
        set_column_type(:fieldKey, "#{dataType}(#{fieldSize})")
      end
    when 'sqlserver'
      puts "Altering #{fieldName} column in #{@info_values["jdbc_database_id"]} - new type/size #{dataType}-#{fieldSize}" if @enable_debug_logging
      @db.alter_table(tableName.to_sym) do
        set_column_type(fieldName.to_sym, dataType.to_sym, size: fieldSize)
      end
    when 'oracle'

    else

    end
  end


end #End Class
