== Kinetic Request CE Space Delete
Deletes a space.

=== Parameters
[Error Handling]
    Determine what to return if an error is encountered. available menu choices: Error Message,Raise Error, default: Error Message
[SpaceSlug]
  The Space slug to be deleted.

=== Sample Configuration
Error Handling:    Error Message
Space Slug:        my-space

=== Results
[Handler Error Message]
  Error message if an error was encountered and Error Handling is set to "Error Message".

=== Detailed Description
This handler deletes a space.