== Kinetic Request CE User Password Change
Changes the password for a User.

=== Parameters
[Error Handling]
    Determine what to return if an error is encountered.
[Space Slug]
  The Space the user exists within. If this value is not entered, the
  Space slug will default to the one configured in info values.
[Username]
  The unique username that identifies the user.
[Password]
  The password for the user.  This value will not be stored in the database
  directly.  A salted hash will be stored instead. This means the password
  can never be recovered.


=== Sample Configuration
Error Handling:         Error Message
Space Slug:
Username::      test@example.com
Password::    secretPassword

=== Results
[Handler Error Message]
  Error message if an error was encountered and Error Handling is set to "Error Message".
[Username]
  The username of the User record.

=== Detailed Description
Changes the password for a User record for the specified space in Kinetic Request CE.

