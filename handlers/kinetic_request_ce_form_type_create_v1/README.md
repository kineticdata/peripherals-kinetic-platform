== Kinetic Request CE Form Type Create
Creates a Form Types in an existing kapp

=== Parameters
[Error Handling]
  Determine what to return if an error is encountered.  menu="Error Message,Raise Error"
[SpaceSlug]
  The Space slug the form type will created in.. If this value is not entered, the
  Space slug will default to the one configured in info values.
[Kapp Slug]
    Slug of the Kapp in which the form type will be created in
[Form Type]
    Name of new Form Type


=== Sample Configuration
Error Handling:    Error Message
Space Slug::       test-space
Kapp Slug::        test-kapp
Form Type::        Test Type 123

=== Results
[Handler Error Message]
  Error message if an error was encountered and Error Handling is set to "Error Message".

=== Detailed Description
This handler creates a form type
