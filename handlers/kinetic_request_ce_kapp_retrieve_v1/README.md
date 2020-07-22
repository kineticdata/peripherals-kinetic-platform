== Kinetic Request CE Kapp Retrieve
Retrieves a kapp from Kinetic Request CE.

=== Parameters
[Error Handling]
    Determine what to return if an error is encountered.
[Space Slug]
  The Space slug to be searched. If this value is not entered, the
  Space slug will default to the one configured in info values.
[KappSlug]
  The Kapp slug to be searched.

=== Sample Configuration
Error Handling:         Error Message
Space Slug:             acme
Kapp Slug:              catalog

=== Results
[Handler Error Message]
  Error message if an error was encountered and Error Handling is set to "Error Message".
[Name]
  Name of the Kapp.
[Slug]
  Slug of the Kapp.
[CreatedAt]
  When the Kapp was created.
[CreatedBy]
  Who created the Kapp.
[UpdatedAt]
  When the Kapp was updated.
[UpdatedBy]
  Who updated the Kapp.
[Attributes]
  Kapp attributes


=== Detailed Description
This handler returns the properties for the kapp record. Includes details,attributes, not categories
categorizations, categoryAttributeDefinitions, formAttributeDefinitions, forms,
kappAttributeDefinitions, securityPolicyDefinitions, securityPolicies, space,
or webhooks. This is not a full kapp export.

