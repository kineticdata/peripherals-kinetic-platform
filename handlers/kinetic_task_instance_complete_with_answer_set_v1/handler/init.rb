# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class KineticTaskInstanceCompleteWithAnswerSetV1
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    # Initialize the handler and pre-load form definitions using the credentials
    # supplied by the task info items.
    preinitialize_on_first_load(@input_document, ['KS_TSK_Trigger','KS_TSK_Instance'])

    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text
    end
  end

  def execute()
    # Retrieve the task instance.  This will be used to populate many of the
    # fields on the trigger record.
    instance_entry = @@remedy_forms['KS_TSK_Instance'].find_entries(
      :single,
      :fields => :all,
      :conditions => [%|'token'="#{@parameters['deferral_token']}"|]
    )
    if instance_entry.nil?
      raise "Could not find task instance with token '#{@parameters['deferral_token']}'"
    end

    # Determine the current results of the specified task instance.  We will
    # ensure that the answer mapping does not override any of the results when
    # the task is completed.
    task_results = REXML::Document.new(instance_entry['task_return_variables'])
    results_names = REXML::XPath.match(task_results, '/results/result').collect do |node|
      node.attribute('name').value
    end

    # Parse the answer set parameter and perform some validation.  We ensure
    # that there is not a question in the answer set labeled "Answer Set"
    # because this would override one of the results.  We also ensure that the
    # answer set contains no questions that would conflict with existing results
    # of the instance (retrieved above).
    answer_set = JSON.parse(@parameters['answer_set'])
    if answer_set.keys.member?("Answer Set")
      raise "Result name conflict due to a question named 'Answer Set'"
    end
    if (answer_set.keys & results_names).length > 0
      raise "Result name conflict due to the following question(s) already being " <<
        "results of the deferred task: #{(answer_set.keys & results_names).join(", ")}"
    end

    # Generate the deferred variables string.  This contains the fully escaped
    # answer set JSON string.  It also contains a result for each of the entries
    # in the answer set.
    deferred_variables = "<results><result name=\"Answer Set\">#{escape(@parameters["answer_set"])}</result>"
    answer_set.each do |key, value|
      deferred_variables << "<result name=\"#{escape(key)}\">#{escape(value)}</result>"
    end
    deferred_variables << '</results>'

    # Create the complete trigger.
    entry = @@remedy_forms['KS_TSK_Trigger'].create_entry!(
      :field_values => {
        'source'               => instance_entry['source'],
        'source_id'            => instance_entry['source_id'],
        'token'                => @parameters['deferral_token'],
        'task_tree_instanceId' => instance_entry['task_tree_instanceId'],
        'task_tree_node_id'    => instance_entry['task_tree_node_id'],
        'loop_index'           => instance_entry['loop_index'],
        'action_type'          => "Complete",
        'last_message'         => "",
        'Description'          => "Complete Task Instance - #{@parameters['deferral_token']}",
        'deferred_variables'   => deferred_variables
      },
      :fields => []
    )

    # Build and return the results xml that will be returned by this handler.
    <<-RESULTS
    <results>
      <result name="Trigger Id">#{escape(entry.id)}</result>
    </results>
    RESULTS
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
    string.to_s.gsub(/[&"><]/) { |special| ESCAPE_CHARACTERS[special] } if string
  end
  # This is a ruby constant that is used by the escape method
  ESCAPE_CHARACTERS = {'&'=>'&amp;', '>'=>'&gt;', '<'=>'&lt;', '"' => '&quot;'}

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