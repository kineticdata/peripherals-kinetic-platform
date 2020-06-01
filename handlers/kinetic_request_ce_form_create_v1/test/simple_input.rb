{
  'info' => {
    'api_server' => 'http://test.kineticdata.com/kinetic',
    'api_username' => 'test',
    'api_password' => '',
    'space_slug' => 'test',
    'enable_debug_logging'=>'yes'
  },
  'parameters' => {
    'error_handling' => 'Error Message',
    'space_slug' => '',
    'kapp_slug' => 'admin',
    'form_json' => %q({
            "name": "Categories",
            "description": "Console for managing categories and subcategories.",
            "slug": "categories",
            "type": "Console",
            "status": "Active",
            "anonymous": false,
            "customHeadContent": null,
            "notes": null,
            "submissionLabelExpression": null,
            "attributes": [
                {
                    "name": "Kapp Slug",
                    "values": [
                        "{{kapp.slug}}"
                    ]
                }
            ],
            "bridgedResources": [],
            "categorizations": [],
            "pages": [
                {
                    "elements": [],
                    "events": [],
                    "name": "Categories",
                    "renderType": "submittable",
                    "type": "page",
                    "advanceCondition": null,
                    "displayCondition": null,
                    "displayPage": "pages/categories/console.jsp"
                }
            ],
            "securityPolicies": []
        })
  }
}
