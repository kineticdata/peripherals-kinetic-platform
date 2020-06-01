== Kinetic Request CE Create Password Reset Token
Creates a password reset token for a user.

=== Parameters
[Error Handling]
  Determine what to return if an error is encountered.
[Space Slug]
  The slug that corresponds to the Space that the user record should be
  associated with.
[Username]
  The unique username that identifies the user.

=== Sample Configuration
Error Handling:         Error Message
Space Slug:
Username:               test@example.com

=== Results
[Handler Error Message]
  Error message if an error was encountered and Error Handling is set to "Error Message".
[Token]
  The token needed for the password reset.

=== Detailed Description
Creates a password reset token for a user. Note: This doesn't send the token to the user,
it only creates the token.
