require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class KineticTaskEngineControlV1
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
    puts "Parameters: #{@parameters.inspect}" if @enable_debug_logging

  end
  
  def execute() 
    error_handling  = @parameters["error_handling"]
    space_slug = @parameters["space_slug"].nil? ? @info_values["space_slug"] : @parameters["space_slug"]
    instance = @parameters["instance"]
    if instance.nil? || instance == "" 
      #puts "instance needs to use #{@info_values["kinetic_task_location"]}" if @enable_debug_logging
      instance =  @info_values["kinetic_task_location"]
    end
    puts "space: #{space_slug}" if @enable_debug_logging
    puts "instance: #{instance}" if @enable_debug_logging
    if instance.include?("${space}") 
      server = instance.gsub("${space}", space_slug)
      puts "Updating instance with space slug: #{server}" if @enable_debug_logging
    elsif !space_slug.to_s.empty?
      server = instance+"/"+space_slug
      puts "Adding Slug to Instance: #{server}" if @enable_debug_logging
    else
      server = instance
      puts "Just using Instance: #{server}" if @enable_debug_logging
    end
    cmd = @parameters["command"].downcase
    user            = @info_values["username"]
    pass            = @info_values["password"]
    
    # API Route with Includes
      task_api_route = server + "/app/api/v2/engine"
      puts "Task API ROUTE: #{task_api_route}" if @enable_debug_logging
    resource = RestClient::Resource.new(task_api_route, { :user => user, :password => pass })

    errormsg = ''
    result = ''
    msg = ''
    if cmd != "restart"
        # Building the object that will be sent to Kinetic Core
        data = {
                :action       => cmd,
                :asynchronous => 'false'
               }.to_json

        task_result = resource.post(data, { :content_type => "json", :accept => "json" })


        json_results = JSON.parse(task_result)
        result = json_results['messageType']
        msg = json_results['message']
        if result != 'success'
            errormsg = msg
        end
    elsif
        # Building the object that will be sent to Kinetic Core
        data = {
                :action       => 'stop',
                :asynchronous => 'false'
               }.to_json

        task_result = resource.post(data, { :content_type => "json", :accept => "json" })


        json_results = JSON.parse(task_result)
        msg = json_results['message']
        data2 = {
                :action       => 'start',
                :asynchronous => 'false'
               }.to_json

        task_result2 = resource.post(data2, { :content_type => "json", :accept => "json" })


        json_results2 = JSON.parse(task_result2)
        result = json_results2['messageType']
        msg = msg+'/'+json_results2['message']
        if result != 'success'
            errormsg = msg
        end
        
    end
    
    puts "Returning results" if @enable_debug_logging
    <<-RESULTS
    <results>
      <result name="Handler Error Message">#{ERB::Util.html_escape(errormsg)}</result>
      <result name="Result">#{ERB::Util.html_escape(result)}</result>
      <result name="Message">#{ERB::Util.html_escape(msg)}</result>
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
