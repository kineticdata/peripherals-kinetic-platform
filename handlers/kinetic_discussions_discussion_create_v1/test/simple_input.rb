{
    'info' => {
	  'discussions_server_url' => 'https://${space}.kinops.io/',
	  'ce_server_url' => 'https://${space}.kinops.io/',
	  'space_slug' => '',
	  'ce_client_id' => '',
	  'ce_client_secret' => ''
    },
    'parameters' => {
	  'error_handling' => 'Raise Error',
	  'space_slug' => '',
	  'title' => 'CREATED FROM A HANDLER',
	  'description' => 'Made by a handler.',
	  'is_archived' => 'false',
	  'is_private' => 'false',
	  'join_policy' => 'Authenticated Users',
	  'owning_users' => ["admin@acme.com"].to_json,
	  'owning_teams' => ["Administrators"].to_json
    }
}
