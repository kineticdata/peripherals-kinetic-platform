{
  'info' => {
    'api_server' => 'http://localhost:8080/kinetic',
    'api_username' => 'user@kineticdata.com',
    'api_password' => '',
    'space_slug' => 'acme',
    'enable_debug_logging'=>'yes'
  },
  'parameters' => {
    'error_handling' => 'Error Message',
    'space_slug' => '',
    'form_slug' => 'group-membership',
    'kapp_slug' => 'admin',
    'form_json' => %q({"bridgedResources": [
                        {
                          "model": "Person",
                          "name": "Person by Username",
                          "order": [

                          ],
                          "parameters": [
                            {
                              "mapping": "${values('Search')}",
                              "name": "Username"
                            }
                          ],
                          "qualification": "By Username",
                          "status": "Active"
                        }
                      ],
                      "pages": [
                        {
                          "advanceCondition": "false",
                          "displayCondition": null,
                          "displayPage": "pages/groups/groupForm.jsp",
                          "elements": [
                            {
                              "type": "section",
                              "renderType": null,
                              "name": "General",
                              "title": null,
                              "visible": true,
                              "omitWhenHidden": null,
                              "renderAttributes": {

                              },
                              "elements": [
                                {
                                  "type": "field",
                                  "name": "Group Name",
                                  "label": "Group Name",
                                  "key": "f3",
                                  "defaultValue": null,
                                  "defaultResourceName": null,
                                  "visible": false,
                                  "enabled": false,
                                  "required": false,
                                  "requiredMessage": null,
                                  "omitWhenHidden": false,
                                  "pattern": null,
                                  "constraints": [

                                  ],
                                  "events": [

                                  ],
                                  "renderAttributes": {

                                  },
                                  "dataType": "string",
                                  "renderType": "text",
                                  "rows": 1
                                },
                                {
                                  "type": "field",
                                  "name": "Search",
                                  "label": "Find a User",
                                  "key": "f1",
                                  "defaultValue": null,
                                  "defaultResourceName": null,
                                  "visible": true,
                                  "enabled": true,
                                  "required": false,
                                  "requiredMessage": null,
                                  "omitWhenHidden": null,
                                  "pattern": null,
                                  "constraints": [

                                  ],
                                  "events": [

                                  ],
                                  "renderAttributes": {
                                    "uses-typeahead": "true",
                                    "typeahead-attribute-to-set": "Username",
                                    "typeahead-bridged-resource": "Person by Username",
                                    "typeahead-fa-class": "fa-user",
                                    "typeahead-attributes-to-show": "Display Name,Username",
                                    "typeahead-placeholder": "Search By Username",
                                    "typeahead-fields-to-set": "Username=Username"
                                  },
                                  "dataType": "string",
                                  "renderType": "text",
                                  "rows": 1
                                },
                                {
                                  "type": "field",
                                  "name": "Username",
                                  "label": "Username",
                                  "key": "f4",
                                  "defaultValue": null,
                                  "defaultResourceName": null,
                                  "visible": true,
                                  "enabled": false,
                                  "required": true,
                                  "requiredMessage": null,
                                  "omitWhenHidden": null,
                                  "pattern": null,
                                  "constraints": [

                                  ],
                                  "events": [

                                  ],
                                  "renderAttributes": {

                                  },
                                  "dataType": "string",
                                  "renderType": "text",
                                  "rows": 1
                                },
                                {
                                  "type": "button",
                                  "label": "Save",
                                  "name": "Save",
                                  "visible": true,
                                  "enabled": true,
                                  "renderType": "submit-page",
                                  "renderAttributes": {
                                    "class": "btn btn-primary"
                                  }
                                },
                                {
                                  "type": "button",
                                  "label": "Cancel",
                                  "name": "Cancel",
                                  "visible": true,
                                  "enabled": true,
                                  "renderType": "custom",
                                  "renderAttributes": {
                                    "class": "btn btn-link cancel-membership"
                                  },
                                  "events": [

                                  ]
                                }
                              ]
                            }
                          ],
                          "events": [
                            {
                              "name": "Initialize Typeahead",
                              "type": "Load",
                              "action": "Custom",
                              "code": "typeAheadSearch(K('form'));",
                              "runIf": "true",
                              "bridgedResourceName": null
                            }
                          ],
                          "name": "Group Member",
                          "renderType": "submittable",
                          "type": "page"
                        }
                      ]
                    })
  }
}
