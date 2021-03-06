require 'rexml/document'
require 'ars_models'

class KineticRequestEmailMessageCreateV2
  # Prepare for execution by pre-loading Ars form definitions, building Hash
  # objects for necessary values, and validating the present state.  This method
  # sets the following instance variables:
  # * @input_document - A REXML::Document object that represents the input Xml.
  # * @debug_logging_enabled - A Boolean value indicating whether logging should
  #   be enabled or disabled.
  # * @parameters - A Hash of parameter names to parameter values.
  # * @field_values - A Hash of KS_MSG_Message database field names to values
  #   that should be set on the message record.
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
      ['KS_MSG_Message', 'KS_MSG_MessageTemplate']
    )

    # Determine if debug logging is enabled.
    @debug_logging_enabled = get_info_value(@input_document, 'enable_debug_logging') == 'Yes'
    log "Logging enabled."

    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text
    end
    log format_hash("Handler Parameters:", @parameters)

    # Retrieve the list of field values that will be written to the approval record
    @field_values = {}
    REXML::XPath.match(@input_document, '/handler/fields/field').each do |node|
      @field_values[node.attribute('name').value] = node.text
    end
    log format_hash("Initial Field Values:", @field_values)
  end

  # Creates a KS_MSG_Message record targeting the recipient specified in the
  # 'To' parameter using the KS_MSG_MessageTemplate record associated to the
  # specified 'Message Template Name' parameter (and the "Kinetic Request"
  # application), and the customer survey submission associated to the specified
  # 'Originating Id' parameter.
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Returns
  # An Xml formatted String representing the return variable results.
  def execute()
    # Use the Message Template Name parameter to retrieve and add the
    # MessageTemplateInstanceID to the @field_values hash.
    @field_values['MessageTemplateInstanceID'] = get_message_template_id(
      @parameters['message_template_name'], @parameters['application_name'])
    log format_hash("Message Record Field Values:", @field_values)

    # Create the entry and only return the instanceId field value
    entry = @@remedy_forms['KS_MSG_Message'].create_entry!(
      :field_values => @field_values, :fields => ['instanceId']
    )
    
    # Build the results xml that will be returned by this handler.
    results = <<-RESULTS
    <results>
      <result name="Instance Id">#{escape(entry['instanceId'])}</result>
    </results>
    RESULTS
    log "Results: \n#{results}"

    # Return the results String
    return results
  end

  ##############################################################################
  # Kinetic handler utility functions
  ##############################################################################

  # Retrieves the Id of the KS_MSG_MessageTemplate record that is associated to
  # the specified message template and application name.
  #
  # Raises an exception if there were no KS_MSG_MessageTemplate records that
  # match the specified message template and application name.
  #
  # ==== Parameters
  # * message_template_name (String) - The name of the desired message template.
  # * application_name (String) - The name of the application that the desired
  #   message template is associated to.
  #
  # ==== Returns
  # A String representing the Instance Id of the located KS_MSG_MessageTemplate
  # record.
  def get_message_template_id(message_template_name, application_name)
    entry = @@remedy_forms['KS_MSG_MessageTemplate'].find_entries(
      :single,
      :fields     => ['instanceId'],
      :conditions => [%`'Message_Template_Name'="#{message_template_name}" AND 'ApplicationName'="#{application_name}"`]
    )
    if entry.nil?
      raise %|Unable to find message template "#{message_template_name}" in application "#{application_name}"|
    end
    entry['instanceId']
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

  # This is a template method that is used to escape results values (returned in
  # execute) that would cause the XML to be invalid.  This method is not
  # necessary if values do not contain character that have special meaning in
  # XML (&, ", <, and >), however it is a good practice to use it for all return
  # variable results in case the value could include one of those characters in
  # the future.  This method can be copied and reused between handlers.
  def escape(string)
    # Globally replace characters based on the ESCAPE_CHARACTERS constant
    string.to_s.gsub(/[&"><]/) { |special| ESCAPE_CHARACTERS[special] }
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
    # Staring with the "header" parameter string, concatenate each of the
    # parameter name/value pairs with a prefix intended to better display the
    # results within the Kinetic Task log.
    hash.inject("#{header}") do |result, (key, value)|
      result << "\n    #{key}: #{value}"
    end
  end

  # This is a sample helper method that illustrates one method for retrieving
  # values from the input document.  As long as your node.xml document follows
  # a consistent format, these type of methods can be copied and reused between
  # handlers.
  def get_info_value(document, name)
    # Retrieve the XML node representing the desird info value
    info_element = REXML::XPath.first(document, "/handler/infos/info[@name='#{name}']")
    # If the desired element is nil, return nil; otherwise return the text value of the element
    info_element.nil? ? nil : info_element.text
  end

  # Calls puts on the argument message if the @debug_logging_enable attribute is
  # true.  This function is meant to clean up code by replacing statements like:
  #   puts("Log message") if @debug_logging_enabled
  # with statements like:
  #   log("Log message")
  def log(message)
    if @debug_logging_enabled
      # Show the line number to help with debugging.
      puts "[#{caller.first.split(":")[-2]}] #{message}"
    end
  end
end
