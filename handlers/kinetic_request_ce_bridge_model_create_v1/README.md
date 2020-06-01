== Kinetic Request CE Bridge Model Create
Creates a Bridge Model in Kinetic Request CE.

=== Parameters
[Error Handling]
  Determine what to return if an error is encountered. menu="Error Message,Raise Error"
[Space Slug]
  The slug of the Space where the Bridge is configured.  If this value is
  not entered, the Space slug will default to the one configured in info values.
[Bridge Model JSON]
  JSON object of the bridge model to import. Must match the format the API accepts and
  can include mappings and qualifiactions.

=== Sample Configuration
Error Handling:         Error Message
Space Slug:
Bridge Model JSON:  ({
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

=== Results
[Handler Error Message]
  Error message if an error was encountered and Error Handling is set to "Error Message".

=== Detailed Description
This handler create a bridge Model from a JSON, which is provided to the API.
