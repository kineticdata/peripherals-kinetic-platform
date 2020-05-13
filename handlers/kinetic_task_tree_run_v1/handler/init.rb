require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class KineticTaskTreeRunV1
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
    endpoint = create_endpoint(@parameters['source'],@parameters['group'],@parameters['tree_name'])
    puts "Starting tree located at following endpoint: #{endpoint}" if @enable_debug_logging

    task_location = RestClient::Resource.new(@info_values['kinetic_task_location'], 
      :user => @info_values['username'], :password => @info_values['password'])

    puts "Sending the run request to the tree" if @enable_debug_logging
    begin
      results = task_location[endpoint].post @parameters['body'], :content_type => 'application/json'
    rescue RestClient::BadRequest => error
      raise StandardError, error.inspect
    end

    json_results = JSON.parse(results)

    puts "Returning results" if @enable_debug_logging
    <<-RESULTS
    <results>
      <result name="run_id">#{json_results['run']['id']}</result>
    </results>
    RESULTS
  end

  # Creates and escapes the endpoint for the Kinetic Task Tree to run
  def create_endpoint(source, group, tree_name)
    puts "Assembling and escaping the endpoint to reach the intended Task Tree" if @enable_debug_logging
    endpoint = "/app/api/v1/run-tree/"
    endpoint += "#{URI.escape(source)}/"
    endpoint += "#{URI.escape(group)}/"
    endpoint += "#{URI.escape(tree_name)}"

    return endpoint
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
