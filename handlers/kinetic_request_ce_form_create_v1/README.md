== Kinetic Core Form Create
Creates a form record in Kinetic Request CE for the specified space.
If the form exists, nothing happens

=== Parameters
[Error Handling]
  Determine what to return if an error is encountered.
[Space Slug]
  The Space the form is being created in. If this value is not entered, the
  Space slug will default to the one configured in info values.
[KappSlug]
  The slug of the Kapp the form is for.
[Form JSON]
  Form Json Structure

=== Sample Configuration
Error Handling:      Error Message
Space Slug:
Kapp Slug:            admin
Form JSON::     ({
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

=== Results
[Handler Error Message]
  Error message if an error was encountered and Error Handling is set to "Error Message".

=== Detailed Description
Creates a form record in Kinetic Request CE for the specified space.
If the form exists, nothing happens