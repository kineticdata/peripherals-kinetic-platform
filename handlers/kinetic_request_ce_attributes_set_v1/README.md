== Kinetic Request CE Attributes Set
Updates one or more Attributes in Kinetic Request CE for the specified object.

Notice: For the "attributes" parameter in simple_input.rb, make sure
to put the JSON object within the single quotes.. example 'attributes' => '[{"name": "test","values": ["Acme"]}]'

=== Parameters
[Error Handling]
  Determine what to return if an error is encountered.
[Space Slug]
  The slug of the Space where the Bridge is configured (defaults to info value if not provided).
[Type]
  What type of attribute should be set.
[Kapp Slug]
  Required for Category or Form. The slug of the kapp where the attributes will be set.
[Type Identifier]
  The identifier that will be used to identify what type to update. A username, name, or slug. Leave
  blank to update all objects for the type that are found.
[Attributes]
  A JSON array of the attributes to update / create. Ex. [{'name': 'Attribute Name','values': ['Attr Value 1']}]
[Create New]
  If the attribute doesn't exist on the object, create it. Default to false (only objects that
  currently have this attribute will be set.

=== Sample Configuration
Error Handling:           Error Message
Space Slug:               test-space
Type:                     Form
Kapp Slug:                test-kapp
Type Identifier:
Attributes:               [{"name": "test","values": ["Acme"]}]
Create New Attribute:     false

=== Results
[Handler Error Message]
  Error message if an error was encountered and Error Handling is set to "Error Message".

=== Detailed Description
This handler will set attributes on one or more of the following objects: Space, Team, User,
User Profile, Kapp, Category, Form. If a type identifier is provided, the handler will only update
that single object. If a type identifier is not provided, the handler will update ALL objects within
the given Space/Kapp (if appropriate). The type identifier will either be an object slug (Kapp,
Category, Form), a name (Team), a username (User, User Profile), or blank (Space). If the
"Create New" parameter is set to 'true' for each form selected, the handler will search for the
attribute and if it exists. If it exists, it will update it to the new value provided. If it doesn't
exist, it will create the new attribute value