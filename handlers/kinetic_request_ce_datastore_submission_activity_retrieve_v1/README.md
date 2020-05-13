== Kinetic Request CE Datastore Submission Activity Retrieve
Retrieves a Datastore Submission Activity Record from Kinetic Request CE.

=== Parameters
[Error Handling]
  Determines what to return if an error is encountered (Error Message or Raise
  Error).
[SpaceSlug]
  The Space the submission is being retrieved from. If this value is not entered, the
  Space slug will default to the one configured in info values.
[Submission Id]
    The Submission the activity is related to.
[Activity Record Id]
    The Activity Record being retreived.

=== Sample Configuration
Error Handling::  Error Message
Space Slug::      acme
Submission Id::   ecfb97fd-4632-11e7-95d0-353fd51a6970
Activity Record Id::  fa20ec41-4632-11e7-94a2-43d2be1dfc7a

=== Results
[Handler Error Message]
  Error message if an error was encountered and Error Handling is set to "Error Message".
[data]
  data field/details of the submission activity.
[description]
  description of the submission activity record. This is often displayed
  as a subheader.
[label]
  This is the label of the submission activity. Often displayed as the
  'name' of the activity.
[id]
  id of the activity record.
[type]
  Type of the activity record. Usually used to determine display properties,
  such as icon, etc. Examples: Approval, Work Order.



=== Detailed Description
This handler returns the properties for the submission activity record.