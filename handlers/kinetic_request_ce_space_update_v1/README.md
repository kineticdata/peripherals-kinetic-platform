== Kinetic Request CE Space Update
Updates a Space.

Notice: For the "attributes" parameter in simple_input.rb, make sure
to put the JSON object within the single quotes.. example 'attributes' => '[{"name": "test","values": ["Acme"]}]'

=== Parameters
[Error Handling]
    Determine what to return if an error is encountered.
[Space Slug]
  The Space being updated. If this value is not entered, the
  Space slug will default to the one configured in info values.
[New Space Slug]
    If changing the space slug enter it here.
[New Space Name]
    If changing the space name enter it here.
[Attributes]
    A JSON map of attributes that should be set. See documentation of valid attribute object
[Bundle Path]
    Set the bundle path.

=== Sample Configuration
Error Handling:   Error Message
Space Slug:       test-space
New Space Slug:   test-space2
New Space Name:   Test Space 2
Attributes:       [{"name": "test","values": ["Acme"]}]
Bundle Path:      test-space-2
Shared Bundle Base: shared-bundle

=== Results
[Handler Error Message] (if appropriate)

=== Detailed Description
This handler updates a space.
