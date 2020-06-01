== Kinetic Request CE Bridge Update
Updates a bridge in Kinetic Request CE.

=== Parameters
[Error Handling]
  Determine what to return if an error is encountered.
[Space Slug]
  The space the submission is being retrieved from (defaults to info value if not provided).
[Original Bridge Name]
  The original name of the Bridge to be updated.
[Updated Bridge Name]
  The updated bridge name
[Updated Bridge URL]
  The updated bridge url
[Updated Bridge Status]
  The updated bridge status, menu="(empty/no change),Active,Inactive"

=== Sample Configuration
Error Handling:          Error Message
Space Slug:              acme
Original Bridge Name:    Kinetic Request CE
Updated Bridge Name:
Updated Bridge URL:      http://server:8080/kinetic-bridgehub/app/api/v1/bridges/request_ce/
Updated Bridge Status:

=== Results
[Handler Error Message]
  Error message if an error was encountered and Error Handling is set to "Error Message".

=== Detailed Description
This handler updates a bridge.
