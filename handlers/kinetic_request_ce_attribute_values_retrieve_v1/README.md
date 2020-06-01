== Kinetic Request CE Attribute Values Retrieve
Returns the attributes for the highest object provided, and all it's parent attributes.

For instance, if just the space slug is provided, the space attributes will be returned.  If the
space and kapp slugs are provided, then the space attributes and the kapp attributes will
be returned.  If the form, kapp, and space slugs are all provided, then the space attributes, the
kapp attributes, and the form attributes will all be returned.

=== Parameters
[Error Handling]
  Determine what to return if an error is encountered.  menu="Error Message,Raise Error"
[Space Slug]
  The Slug of the Space to search. If blank, the Handlers Info Space Slug value will be used
[Kapp Slug]
  The Slug of the Kapp to search.
[Form Slug]
  The Slug of the Form to search.

=== Sample Configuration
Error Handling:           Error Message
Space Slug:               test-space
Kapp Slug:                test-kapp
Form Slug:                test-form

=== Results
[Handler Error Message] (if appropriate)
[Space Attributes]
   The space attributes
[Kapp Attributes] (if appropriate)
   The kapp attributes
[Form Attributes] (if appropriate)
   The form attributes

=== Detailed Description
Retrieves space attributes and optionally kapp and form attributes.
