require 'rexml/document'
require 'ars_models'

class KineticTaskTriggerResumeV1
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    # Initialize the handler and pre-load form definitions using the credentials
    # supplied by the task info items.
    preinitialize_on_first_load(
      @input_document,
      ['KS_TSK_Trigger']
    )

    # Retrieve parameters from the input xml and store them as instance
    # variables available to the rest of this execution.
    @trigger_id = get_parameter_value(@input_document, 'trigger_id')
  end

  def execute()
    # Retrieve the task trigger with the specified id.
    trigger = @@remedy_forms['KS_TSK_Trigger'].find_entries(
      :single,
      :conditions => [%|'Request ID' = "#{@trigger_id}"|],
      :fields => ['Status'])

    # If the trigger could not be found raise an exception.
    if trigger.nil?
      raise("Could not find a task trigger with id #{@trigger_id}")
    end

    # If the trigger does not have a status of paused raise an exception.
    if trigger['Status'] != 'Paused'
      raise("Task trigger with id #{@trigger_id} does not have a status of Paused")
    end

    # Finally, update the status of the trigger
    trigger.update_attributes!('Status' => 'Unpaused')

    # Return the results XML
    "<results/>"
  end

  # Preinitialize expensive operations that are not task node dependent (IE
  # don't change based on the input parameters passed via xml to the #initialize
  # method).  This will very frequently utilize task info items to do things
  # such as pre-load a Remedy form or generate a Remedy proxy user.
  def preinitialize_on_first_load(input_document, form_names)
    # Unless this method has already been called
    unless self.class.class_variable_defined?('@@preinitialized')
      # Initialize a remedy context (login) account to execute the Remedy queries
      @@remedy_context = ArsModels::Context.new(
        :server => get_info_value(input_document, 'server'),
        :username => get_info_value(input_document, 'username'),
        :password => get_info_value(input_document, 'password'),
        :port => get_info_value(input_document, 'port'),
        :prognum => get_info_value(input_document, 'prognum'),
        :authentication => get_info_value(input_document, 'authentication')
      )

      # Initialize the remedy forms that will be used by this handler.
      @@remedy_forms = form_names.inject({}) do |hash, form_name|
        hash.merge!(form_name => ArsModels::Form.find(form_name, :context => @@remedy_context))
      end

      # Store that we are preinitialized so that this method is not called a second time
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

  # This is a sample helper method that illustrates one method for retrieving
  # values from the input document.  As long as your node.xml document follows
  # a consistent format, these type of methods can be copied and reused between
  # handlers.
  def get_parameter_value(document, name)
    # Retrieve the XML node representing the desird info value
    parameter_element = REXML::XPath.first(document, "/handler/parameters/parameter[@name='#{name}']")
    # If the desired element is nil, return nil; otherwise return the text value of the element
    parameter_element.nil? ? nil : parameter_element.text
  end
end