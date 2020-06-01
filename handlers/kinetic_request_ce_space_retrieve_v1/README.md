== Kinetic Request CE Space Retrieve
Retrieves a space from Kinetic Request CE.

=== Parameters
[Error Handling]
    Determine what to return if an error is encountered. available menu choices: Error Message,Raise Error, default: Error Message
[SpaceSlug]
  The Space slug to be searched. If this value is not entered, the
  Space slug will default to the one configured in info values.

=== Sample Configuration
Error Handling:   Error Message
Space Slug:       acme

=== Results
[Handler Error Message]
  Error message if an error was encountered and Error Handling is set to "Error Message".
[Name]
  Name of the Space.
[Slug]
  Slug of the Space.
[CreatedAt]
  When the Space was created.
[CreatedBy]
  Who created the Space.
[UpdatedAt]
  When the Space was updated.
[UpdatedBy]
  Who updated the Space.
[Attributes]
  Space attributes,

=== Detailed Description
This handler returns the properties for the space record.