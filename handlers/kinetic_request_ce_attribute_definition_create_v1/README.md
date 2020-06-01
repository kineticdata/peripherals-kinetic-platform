== Kinetic Request CE Attribute Definition Create
Creates an Attribute Definition in Kinetic Request CE.

=== Parameters
[Error Handling]
  Determine what to return if an error is encountered.
[Space Slug]
  The slug of the Space where the Bridge is configured (defaults to info value if not provided).
[Type]
  What type of attribute definition should be created.
[Kapp Slug]
  Required for Kapp, Category, or Form. The slug of the kapp where the definition will be created.
[Name]
  Name of the new attribute.
[Description]
  Optional description for the new attribute.
[Allows Multiple]
  Sets allows multiple to true or false. Defaults to false.


=== Sample Configuration
Error Handling:      Error Message
Space Slug:
Type:                Kapp
Kapp Slug:           catalog
Name:                Test Attribute 123
Description:         Attribute description goes here
Allows Multiple:     false

=== Results
[Handler Error Message]
  Error message if an error was encountered and Error Handling is set to "Error Message".

=== Detailed Description
This handler creates an attribute definition for any of the following types: Space, Team, User, User
Profile, Kapp, Category, or Form. The API Route is determined based on the type inputted along with
the Kapp Slug (only needed for Kapp, Category, or Form). Once the API Route and data object has been
built up, the call is made to that endpoint and will return an empty response (if successful) or an
error is one was encountered.