{
  'info' => {
    'api_server' => 'foo',
    'api_username' => 'bar',
    'api_password' => 'baz',
    'enable_debug_logging'=>'yes'
  },
  'parameters' => {
    'error_handling' => 'Raise Error',
    'agent_slug' => 'test-slug',
    'handler_slug' => 'on-prem-incident-retrieve',
    'payload' => 
      '{
        "error_handling": "Raise Error",
        "incident_id": "INC-1234",
        "summary": "Incident Summary",
        "description": "Incident Description..."
      }',
  }
}
