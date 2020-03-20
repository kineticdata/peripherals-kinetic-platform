{
  'info' => {
    'api_server' => 'http://localhost:8082/kinetic-bridgehub',
    'api_username' => 'admin',
    'api_password' => 'foobar',
    'enable_debug_logging'=>'yes'
  },
  'parameters' => {
    'error_handling' => 'Raise Error',
    'handler_space' => 'kd-developers',
    'handler_slug' => 'submission_retrieve',
    'payload' => 
      '{
        "error_handling": "Raise Error",
        "space_slug" : "",
        "retrieve_by" : "Id",
        "kapp_slug" : "services",
        "form_slug" : "employee-onboarding",
        "query" : "",
        "submission_id" : "ad02d353-3f5e-11e9-badc-09cbd20474c2"
      }',
  }
}
