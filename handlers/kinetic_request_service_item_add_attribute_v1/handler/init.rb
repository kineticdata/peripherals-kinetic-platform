require 'rexml/document'
require 'ars_models'

class KineticRequestServiceItemAddAttributeV1
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    # Initialize the handler and pre-load form definitions using the credentials
    # supplied by the task info items.
    preinitialize_on_first_load(
      @input_document,
      ['KS_SRV_SurveyTemplate', 'KS_ATT_AttributeType', 'KS_ATT_AttributeInstance']
    )
    
    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text
    end
  end

  def execute()
    # Query to retrieve the service item record.  The instanceId of the service
    # item record will be used to query the attribute form.  If there is no record
    # return by this query we raise an exception.
    service_item_qualification = [
      %|'Category' = "#{@parameters['catalog_name']}"|,
      %|'Survey_Template_Name' = "#{@parameters['service_item_name']}"|
    ].join(" AND ")
    service_item_entry = @@remedy_forms['KS_SRV_SurveyTemplate'].find_entries(
      :single, 
      :conditions => [service_item_qualification],
      :fields => ['instanceId']
    )
    if service_item_entry.nil?
      raise(%|Could not find service item named "#{@parameters['service_item_name']} | <<
          %|in the catalog "#{@parameters['catalog_name']}"|)
    end

    # Query the attribute type form to retrieve some attribute data needed to create
    # the attribute instance record.
    attribute_type_qualification = [
      %|'Attribute_Type' = "#{@parameters['attribute_name']}"|,
      %|'Application' = "Kinetic Request"|,
      %|'Attribute_Parent_Form' = "KS_SRV_SurveyTemplate"|
    ].join(" AND ")
    attribute_type_entry = @@remedy_forms['KS_ATT_AttributeType'].find_entries(
      :single,
      :conditions => [attribute_type_qualification],
      :fields => ['instanceId', 'Data Type Developer Name']
    )
    if attribute_type_entry.nil?
      raise(%|Could not find attribute type with name "#{@parameters['attribute_name']}".  | <<
          %|This is the qualification that was used: #{attribute_type_qualification}|)
    end

    # Create an attribute instance record for the given service item with the specified
    # attribute name and value.
    attribute_instance_enry = @@remedy_forms['KS_ATT_AttributeInstance'].create_entry!(
      :field_values => {
        'Application'                 => "Kinetic Request",
        'Attribute_Parent_InstanceId' => service_item_entry['instanceId'],
        'Attribute_Type_Instance_ID'  => attribute_type_entry['instanceId'],
        'Attribute_Data_Type'         => attribute_type_entry['Data Type Developer Name'],
        'Attribute Type Name'         => @parameters['attribute_name'],
        'Character_Value'             => @parameters['attribute_value']
      },
      :fields => []
    )

    # Build and return the results string returned by this handler.
    <<-RESULTS
    <results>
    </results>
    RESULTS
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
end