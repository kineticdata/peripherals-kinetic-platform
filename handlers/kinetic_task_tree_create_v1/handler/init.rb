require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class KineticTaskTreeCreateV1
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)
    
    # Store the info values in a Hash of info names to values.
    @info_values = {}
    REXML::XPath.each(@input_document,"/handler/infos/info") { |item|
      @info_values[item.attributes['name']] = item.text  
    }
    
    # Retrieve all of the handler parameters and store them in a hash attribute
    # named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, 'handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text.to_s
    end

    @enable_debug_logging = @info_values['enable_debug_logging'] == 'Yes'
  end
  
  def execute() 
    error_handling  = @parameters["error_handling"]
    
    api_route = "#{@info_values['kinetic_task_location']}/app/api/v1/import-tree"

    resource = RestClient::Resource.new(api_route, { :user => @info_values['username'], :password => @info_values['password'] })

    # Build xml document to update
    inputTree = REXML::Document.new(@parameters['body'])
    # Replace the SourceName in the tree provided
    REXML::XPath.match(inputTree, 'tree/sourceName')[0].text = "#{@parameters['source']}"
    # Replace the SourceGroup in the tree provided
    REXML::XPath.match(inputTree, 'tree/sourceGroup')[0].text = "#{@parameters['group']}"

    # Build a body to be passed in the rest call
    body = {"structure" => inputTree.to_s}

    puts "Sending the request to import the tree" if @enable_debug_logging
    results = resource.post body.to_json, :content_type => 'application/json'
    json_results = JSON.parse(results)

    puts "Returning results" if @enable_debug_logging
    <<-RESULTS
    <results>
      <result name="Handler Error Message"></result>
      <result name="tree_id">#{json_results['tree']['id']}</result>
    </results>
    RESULTS

    rescue RestClient::Exception => error
      error_message = JSON.parse(error.response)["message"]
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
