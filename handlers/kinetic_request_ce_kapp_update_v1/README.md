== Kinetic Request CE Kapp Update
Updates a Kapp.

Notice: For the "attributes" parameter in simple_input.rb, make sure
to put the JSON object within the single quotes.. example 'attributes' => '[{"name": "test","values": ["Acme"]}]'

=== Parameters
[Error Handling]
  Determine what to return if an error is encountered.
[Space Slug]
  The Space slug the kapp is in. If this value is not entered, the
  Space slug will default to the one configured in info values.
[Orig Kapp Slug]
    Slug of the Kapp to Change
[New Kapp Slug]
    If changing the kapp slug enter it here.
[New Kapp Name]
    If changing the kapp name enter it here.
[Attributes]
    A JSON map of attributes that should be set. Ex. [{'name': 'Attribute Name','values': ['Attr Value 1']}]
[Bundle Path]
	Set the kapp bundle path.


=== Sample Configuration
Error Handling:   Error Message
Space Slug:       test-space
Orig Kapp Slug:   test-kapp
New Kapp Slug:    test-kapp2
New Kapp Name:    Test Kapp 2
Attributes:       [{"name": "test","values": ["Acme"]}]
Bundle Path:      request-ce-bundle

=== Results
[Handler Error Message]
  Error message if an error was encountered and Error Handling is set to "Error Message".

=== Detailed Description
This handler updates a kapp.

