# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), "dependencies"))

class KineticRequestCeFormatAnswersV1
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

    api_username    = URI.encode(@info_values["api_username"])
    api_password    = @info_values["api_password"]
    kapp_slug       = @parameters["kapp_slug"]
    submission_id   = @parameters["submission_id"]
    answer_set   = @parameters["answer_set"]
    field_aliases = @parameters["field_aliases"]
    mode = @parameters["mode"]
    included_fields = @parameters["included_fields"]
    excluded_fields = @parameters["excluded_fields"]



    if !submission_id.nil? && submission_id != ""
    api_route = "#{server}/app/api/v1/submissions/#{submission_id}?include=values"

    puts "API ROUTE: #{api_route}" if @enable_debug_logging

    resource = RestClient::Resource.new(api_route, { :user => api_username, :password => api_password })

    response = resource.get

    submission = JSON.parse(response)

    @values = submission["submission"]["values"]
    elsif !answer_set.nil? && answer_set != ""
       @values = JSON.parse(answer_set)
    else
        return <<-RESULTS
        <results>
          <result name="Handler Error Message">Either a Submission ID or JSON answer set needs to be provided.</result>
        </results>
        RESULTS
    end

    #remove excluded fields

    if !excluded_fields.nil? && excluded_fields != ""
    puts "Removing excluded fields" if @enable_debug_logging
        exclude_fields = excluded_fields.split(",")

        @values.each do |fieldName,answer|
            if exclude_fields.include?(fieldName)
                @values.delete(fieldName)
            end
        end
    end

    if mode == "Some" && !included_fields.nil? && included_fields != ""
    puts "Only include included fields" if @enable_debug_logging
        #only include included fields
        include_fields = included_fields.split(",")
        @values = @values.select{|fieldName| include_fields.include?(fieldName)}
    end

    #process Aliases for the answer set (JSON) getting created
    answerSet = processAliases(@values, field_aliases)
    answerSetJSON = answerSet.to_json

    #create HTML table
    table = "<table><tr><th>Field</th><th>Answer Value</th></tr>"
    answerSet.keys.each do |key|
        table << "<tr><td>#{key}</td><td>#{answerSet[key]}</td></tr>"
    end
    table << "</table>"

    #create List
    list = ""
    answerSet.keys.each do |key|
      list << "#{key}: #{answerSet[key]}\n"
    end

    # Build the results to be returned by this handler
    results = "<results><result name='Handler Error Message'></result>
               <result name='JSON'>#{escape(answerSetJSON)}</result>
               <result name='HTML'>#{escape(escape_html(table))}</result>
               <result name='List'>#{escape(list)}</result>"

    @values.each do |fieldName,answer|
      if answer.kind_of?(Array)
        results += "<result name='#{fieldName}'>#{escape(answer.join(" , "))}</result>"
      else
        results += "<result name='#{fieldName}'>#{escape(answer)}</result>"
      end
    end

    results += "</results>"

    rescue RestClient::Exception => error
      error_message = JSON.parse(error.response)["error"]
      if error_handling == "Raise Error"
        raise error_message
      else
        <<-RESULTS
        <results>
          <result name="Handler Error Message">#{error.http_code}: #{escape(error_message)}</result>
        </results>
        RESULTS
      end
  end

  #function to swap out the names of the original fields for the desired aliases in the dataset
  def processAliases(values, aliases)
    aliasesArray = aliases.split(",")
    aliasHash = {}
    #create array hash
    aliasesArray.each do |thisAlias|
       thisAliasArray = thisAlias.split("=")
       aliasHash[thisAliasArray[0]] = thisAliasArray[1]
    end
    newValues = {}
    initialValues = Hash[values]
    initialValues.each do |fieldName,answer|
      #If there is an alias for this fieldName, swap it out.
      if aliasHash.has_key?(fieldName)
        newValues[aliasHash[fieldName]] = answer
        initialValues.delete(fieldName)
      end
    end
    initialValues.merge!(newValues)

    return initialValues
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
  ESCAPE_CHARACTERS = {
    "&" => "&amp;",
    "<" => "&lt;",
    ">" => "&gt;",
    "'" => "&#39;",
    '"' => "&quot;",
    "/" => "&#47;",
    "#" => "&#35;",
    " " => "&nbsp;",
    "\\" => "&#92;",
    "\r" => "<br>",
    "\n" => "<br>"
  }
    def escape_html(string)
    # Globally replace characters based on the ESCAPE_HTML constant
    string.to_s.gsub(/[&"><'\/\\\s\r\n#]/) { |special| ESCAPE_HTML[special] } if string
  end
ESCAPE_HTML = {
      "&" => "&amp;",
      "<" => "&lt;",
      ">" => "&gt;",
      "'" => "&#39;",
      '"' => "&quot;",
      "/" => "&#47;",
	  "#" => "&#35;",
	  " " => "&nbsp;",
	  "\\" => "&#92;",
	  "\r" => "<br>",
	  "\n" => "<br>"

    }

      # Builds a string that is formatted specifically for the Kinetic Task log file
  # by concatenating the provided header String with each of the provided hash
  # name/value pairs.  The String format looks like:
  #   HEADER
  #       KEY1: VAL1
  #       KEY2: VAL2
  # For example, given:
  #   field_values = {'Field 1' => "Value 1", 'Field 2' => "Value 2"}
  #   format_hash("Field Values:", field_values)
  # would produce:
  #   Field Values:
  #       Field 1: Value 1
  #       Field 2: Value 2
  def format_hash(header, hash)
    # Staring with the "header" parameter string, concatenate each of the
    # parameter name/value pairs with a prefix intended to better display the
    # results within the Kinetic Task log.
    hash.inject(header) do |result, (key, value)|
      result << "\n    #{key}: #{value}"
    end
  end

end


