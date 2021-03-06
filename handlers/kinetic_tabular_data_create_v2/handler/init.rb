require 'rexml/document'
require 'ars_models'
require 'pp'
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))



class KineticTabularDataCreateV2

LABEL_FIELD_START = 899000100
VALUE_FIELD_START = 899000200

  # Prepare for execution by pre-loading Ars form definitions, building Hash
  # objects for necessary values, and validating the present state.  This method
  # sets the following instance variables:
  # * @input_document - A REXML::Document object that represents the input Xml.
  # * @debug_logging_enabled - A Boolean value indicating whether logging should
  #   be enabled or disabled.
  # * @parameters - A Hash of parameter names to parameter values.
  # * @field_values - A Hash of KS_SRV_CustomerSurvey_base database field names
  #   to the values to be used for the approval record.
  # * @fields_to_clone - An array of KS_SRV_CustomerSurvey_base database field
  #   names that should be copied from the originating record to the approval
  #   record.
  # * @additional_fields - An Array of KS_SRV_CustomerSurvey_base database field
  #   names that need to be retrieved with the originating record but that are
  #   not set on the approval record.
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
    # Initialize the handler and pre-load form definitions using the credentials
    # supplied by the task info items.
    preinitialize_on_first_load(
      @input_document,
      [
        'CUSTOM:KS_SRV_TableData_base'
      ]
    )

    # Determine if debug logging is enabled.
    @debug_logging_enabled = get_info_value(@input_document, 'enable_debug_logging') == 'Yes'
    puts("Logging enabled.") if @debug_logging_enabled

    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text
    end
    puts(format_hash("Handler Parameters:", @parameters)) if @debug_logging_enabled

    
    
  end


  def execute()   
  
  id_list = "<request_ids>"
  instance_id_list = "<instance_ids>"
  row_count = 0
  
  json_struct = JSON.parse(@parameters['input_json'])
  
  
 
 
 json_struct.each do |elm|
   fields = json_to_field_hash(elm)
   
  fields['CustomerSurveyInstanceID'] = @parameters['originating_id']
  fields['Table Name'] = @parameters['table_name']
  fields['Survey_Template_Name'] = @parameters['template_name']
  fields['SurveyInstanceID'] = @parameters['template_id']

   
   entry = @@remedy_forms['CUSTOM:KS_SRV_TableData_base'].create_entry!(
      :field_values => fields,
      :fields       => ['instanceId']
    )
   id_list = "#{id_list}<request_id>#{entry.id}</request_id>"
   instance_id_list = "#{instance_id_list}<instance_id>#{entry['instanceId']}</instance_id>"
   row_count = row_count + 1
   end  
  
	id_list = "#{id_list}</request_ids>" 
	instance_id_list = "#{instance_id_list}</instance_ids>"	
	
    # Build the results xml that will be returned by this handler.
    results = <<-RESULTS
    <results>
      <result name="Table Data Request Id List">#{escape(id_list)}</result>
	  <result name="Table Data Instance Id List">#{escape(instance_id_list)}</result>
      <result name="Table Data Row Count">#{row_count}</result>	  
    </results>
    RESULTS
    puts("Results: \n#{results}") if @debug_logging_enabled

    # Return the results String
    return results
  end

def json_to_field_hash(input)
field_hash = {}
start_field_label = LABEL_FIELD_START
start_field_value = VALUE_FIELD_START

input.keys.each do |key|
  field_hash[get_field_name(start_field_label)] = key
  field_hash[get_field_name(start_field_value)] = input[key]
  start_field_label = start_field_label + 1
  start_field_value = start_field_value + 1
end
  return field_hash
end
  
def get_field_name(field_id)
field_name = @@remedy_forms['CUSTOM:KS_SRV_TableData_base'].field_for(field_id.to_i).name
end
  ##############################################################################
  # General handler utility functions
  ##############################################################################

  # Preinitialize expensive operations that are not task node dependent (IE
  # don't change based on the input parameters passed via xml to the #initialize
  # method).  This will very frequently utilize task info items to do things
  # such as pre-load a Remedy form or generate a Remedy proxy user.
  def preinitialize_on_first_load(input_document, form_names)
    # Unless this method has already been called...
    unless self.class.class_variable_defined?('@@preinitialized')
      # Initialize a remedy context (login) account to execute the Remedy queries.
      @@remedy_context = ArsModels::Context.new(
        :server         => get_info_value(input_document, 'server'),
        :username       => get_info_value(input_document, 'username'),
        :password       => get_info_value(input_document, 'password'),
        :port           => get_info_value(input_document, 'port'),
        :prognum        => get_info_value(input_document, 'prognum'),
        :authentication => get_info_value(input_document, 'authentication')
      )
      # Initialize the remedy forms that will be used by this handler.
      @@remedy_forms = form_names.inject({}) do |hash, form_name|
        hash.merge!(form_name => ArsModels::Form.find(form_name, :context => @@remedy_context))
      end
      # Store that we are preinitialized so that this method is not called twice.
      @@preinitialized = true
    end
  end
  
  def create_value_hash(input)
  field_values = {}
  
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
    # Starting with the "header" parameter string, concatenate each of the
    # parameter name/value pairs with a prefix intended to better display the
    # results within the Kinetic Task log.
    hash.inject(header) do |result, (key, value)|
      result << "\n    #{key}: #{value}"
    end
  end

  # This is a sample helper method that illustrates one method for retrieving
  # values from the input document.  As long as your node.xml document follows
  # a consistent format, these type of methods can be copied and reused between
  # handlers.
  def get_info_value(document, name)
    # Retrieve the XML node representing the desired info value
    info_element = REXML::XPath.first(document, "/handler/infos/info[@name='#{name}']")
    # If the desired element is nil, return nil; otherwise return the text value of the element
    info_element.nil? ? nil : info_element.text
  end

  
end