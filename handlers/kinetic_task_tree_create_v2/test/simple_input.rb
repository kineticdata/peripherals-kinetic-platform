{
  'info' =>
  {
    'username' => '',
    'password' => '',
    'kinetic_task_location' => 'https://test.kinops.io/kinetic-task',
    'enable_debug_logging' => 'Yes',
    'signature_key' => nil,
    'signature_secret' => nil
  },
  'parameters' =>
  {
    'signature_key' => nil,
    'signature_secret' => nil,
    'error_handling' => 'Error Message',
    'source' => 'Kinetic Request CE',
    'group' => 'queue > test-tree',
    'body' => %{<tree schema_version="1.0">
                    <sourceName>Kinetic Request CE</sourceName>
                    <sourceGroup>queue > admin-workfow-errors</sourceGroup>
                    <type>Tree</type>
                    <status>Active</status>
                    <taskTree schema_version="1.0" version="" builder_version="">
                        <name>Complete</name>
                        <author/>
                        <notes/>
                        <lastID>1</lastID>
                        <request>
                            <task definition_id="system_start_v1" id="start" name="Start" x="10" y="10">
                                <version>1</version>
                                <configured>true</configured>
                                <defers>false</defers>
                                <deferrable>false</deferrable>
                                <visible>false</visible>
                                <parameters/>
                                <messages/>
                                <dependents><task type="Complete" label="" value="">utilities_create_trigger_v1_1</task></dependents>
                            </task>

                            <task name="Complete Trigger" id="utilities_create_trigger_v1_1" definition_id="utilities_create_trigger_v1" x="279.6875" y="85.6875">
                          <version>1</version>
                          <configured>true</configured>
                          <defers>false</defers>
                          <deferrable>false</deferrable>
                          <visible>true</visible>
                          <parameters>
                            <parameter id="action_type" label="Action Type" menu="Update,Complete" required="true" tooltip="">Complete</parameter>
                            <parameter id="deferral_token" label="Deferral Token" required="true" tooltip="" menu="">&lt;%= @values['Deferral Token']%&gt;</parameter>
                            <parameter id="deferred_variables" label="Deferred Results" required="false" tooltip="" menu=""/>
                            <parameter id="message" label="Message" required="false" tooltip="" menu=""/>
                        </parameters><messages>
                            <message type="Create"/>
                            <message type="Update"/>
                            <message type="Complete"/>
                          </messages>
                          <dependents/>
                        </task>
                          </request>
                    </taskTree>
                </tree>
                }
    }
}
