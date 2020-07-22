== Kinetic Request CE Submission Update
Updates a submission.

=== Parameters
[Error Handling]
  Determine what to return if an error is encountered.
[Space Slug]
  The Space the submission is being retrieved from (defaults to info value if not provided).
[Submission Id]
  The id of the submission being updated.
[State]
  The value used to set the submission state.
[Values]
  A JSON map of field names to values that should be set.
[Current Page Name]
  Set the current page name.
[Current Page Navigation]
  Set the current page navigation.
[Origin ID]
  Set the origin ID.
[Parent ID]
  Set the parent ID.

=== Sample Configuration
Error Handling:         Error Message
Space Slug:
Submission Id:          02edc019-e553-11e5-9c32-351e42075226
State:                  Submitted
Values:                 {"First_Name": "John", "Last_Name": "Doe"}
Current Page Name:
Current Page Navigation:
Origin ID:
Parent ID:

=== Results
[Handler Error Message]
  Error message if an error was encountered and Error Handling is set to "Error Message".

=== Detailed Description
This handler updates a submission.

