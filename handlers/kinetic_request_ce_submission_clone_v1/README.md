# Kinetic Request CE Submission Clone
Clones a submission

## Parameters
[Error Handling]
  Determine what to return if an error is encountered.
[Space Slug]
  The Space the submission is being retrieved from (defaults to info value if not provided).
[Original Submission Id]
  The id of the submission being updated.
[State]
  The value used to set the submission state.
[Overridden Value]
  A JSON map of field names to values that should be set.
[Current Page Name]
  Set the current page name.
[Current Page Navigation]
  Set the current page navigation.
[Origin ID]
  Set the origin ID.
[Parent ID]
  Set the parent ID.
[Type]
  Type of Submission (overrides forms type).

## Sample Configuration
Error Handling:            Error Message
Space Slug:
Original Submission Id:    02edc019-e553-11e5-9c32-351e42075226
State:                     Submitted
Overridden Values:          {"Text":"TestFromAIPOverwrite"}
Current Page Name:
Current Page Navigation:
Origin ID:
Parent ID:
Type:                      Approval

## Results
[Handler Error Message]
  Error message if an error was encountered and Error Handling is set to "Error Message".
[Submission ID]
  Id for the new submission that was cloned.

## Detailed Description
...