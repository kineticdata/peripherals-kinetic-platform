== Kinetic Request CE Space Submission Activity Update
Updates a submission activity record in Kinetic Request CE.

=== Parameters
[Error Handling]
  Determines what to return if an error is encountered (Error Message or Raise
  Error).
[Space Slug]
  The Space the submission exists in. If this value is not entered, the
  Space slug will default to the one configured in info values.
[Submission Id]
  The id of the submission for which the activity is being created for.
[Submission Activity Id]
  The id of the submission for which the activity is being created for.
[Label]
  The label for the submission activity.
[Description]
  The description of the submission activity.
[Type]
  Specifies the a submission activity 'Type', which should indicate what type of
  data is included.
[Data]
  Additional data that can be used by resources consuming the submission
  activity record (for example a Request bundle may render submission details
  based upon JSON content in the activity data).

=== Sample Configuration
Error Handling:          Error Message
Space Slug:              acme
Submission Id:           288671e8-f3ca-11e6-bc64-92361f002671
Submission Activity Id:  36fc0ee0-f3ca-11e6-bc64-92361f002671
Label:                   Awaiting Approval - aaron.approver@acme.com
Description:             An approval was created and assigned to Aaron Approver.
Type:                    Approval
Data:                    a025be8e-f3ca-11e6-bc64-92361f002671

=== Results
[Handler Error Message]
  Error message if an error was encountered and Error Handling is set to "Error Message".

=== Detailed Description
...
