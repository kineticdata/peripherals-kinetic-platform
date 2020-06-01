{
  'info' => {
    'api_server' => 'http://1.1.1.1:8080/kinetic',
    'api_username' => '',
    'api_password' => '',
    'space_slug' => '',
    'enable_debug_logging'=>'yes'
  },
  'parameters' => {
    'error_handling' => 'Error Message',
    'space_slug' => '',
    'modelJSON' => %q({
                        "activeMappingName": "Person",
                        "attributes": [
                          {
                            "name": "Display Name"
                          },
                          {
                            "name": "Email"
                          },
                          {
                            "name": "Username"
                          }
                        ],
                        "mappings": [
                          {
                            "attributes": [
                              {
                                "name": "Display Name",
                                "structureField": "${fields('displayName')}"
                              },
                              {
                                "name": "Username",
                                "structureField": "${fields('username')}"
                              },
                              {
                                "name": "Email",
                                "structureField": "${fields('email')}"
                              }
                            ],
                            "bridgeName": "Kinetic Core",
                            "name": "Person",
                            "qualifications": [
                              {
                                "name": "By Email",
                                "query": "email=%${parameters('Email')}%"
                              },
                              {
                                "name": "By Username",
                                "query": "username=%${parameters('Username')}%"
                              }
                            ],
                            "structure": "Users"
                          }
                        ],
                        "name": "Person",
                        "qualifications": [
                          {
                            "name": "By Email",
                            "parameters": [
                              {
                                "name": "Email",
                                "notes": null
                              }
                            ],
                            "resultType": "Multiple"
                          },
                          {
                            "name": "By Username",
                            "parameters": [
                              {
                                "name": "Username",
                                "notes": null
                              }
                            ],
                            "resultType": "Multiple"
                          }
                        ],
                        "status": "Active"
                      })
  }
}
