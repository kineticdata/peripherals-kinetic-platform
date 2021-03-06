require 'digest'
require 'base64'

require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class KineticTaskRunDeleteV1
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

    # used to determine if the request should be signed
    @signature_key = nil
    if @parameters['signature_key'] != ""
      @signature_key = @parameters['signature_key']
      puts "Using signature_key from parameters: #{@signature_key}" if @enable_debug_logging
    elsif @info_values['signature_key'] != ""
      @signature_key = @info_values['signature_key']
      puts "Using signature_key from info values: #{@signature_key}" if @enable_debug_logging
    end

    @signature_secret = nil
    if @parameters['signature_secret'] != ""
      @signature_secret = @parameters['signature_secret']
      puts "Using signature_secret from parameters" if @enable_debug_logging
    elsif @info_values['signature_secret'] != ""
      @signature_secret = @info_values['signature_secret']
      puts "Using signature_secret from info values" if @enable_debug_logging
    end

  end

  def execute()
    endpoint = "/app/api/v2/runs/#{@parameters['run_id']}"
    puts "Deleting run located at following endpoint: #{endpoint}" if @enable_debug_logging

    task_location = RestClient::Resource.new(@info_values['kinetic_task_location'],
      :user => @info_values['username'], :password => @info_values['password'])

    puts "Sending the delete request" if @enable_debug_logging
    begin
      headers = {
        :content_type => 'application/json'
      }
      if @signature_key && @signature_secret
        sign = signature
        puts "Adding signature: #{sign}" if @enable_debug_logging
        headers['X-Kinetic-SignatureKey'] = @signature_key
        headers['X-Kinetic-Signature'] = sign
      end

      results = task_location[endpoint].delete(headers)
    rescue RestClient::BadRequest => error
      raise StandardError, error.inspect
    end

    json_results = JSON.parse(results)

    puts "Returning results" if @enable_debug_logging
    <<-RESULTS
    <results>
      <result name="messageType">#{escape(json_results['messageType'])}</result>
      <result name="message">#{escape(json_results['message'])}</result>
    </results>
    RESULTS
  end

  def signature
    data = @signature_secret + @parameters['body']
    sha1 = Digest::SHA1.digest(data)
    Base64.urlsafe_encode64(sha1)
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
