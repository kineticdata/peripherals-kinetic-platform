== Kinetic Request CE Cascading Attribute Value Retrieve
Returns the matched value of the "Property to Return" parameter for the given scope. If the Context is Submission or Datastore Submission, this handler
will search for a matching submission value, if none found, it will search the form, then kapp (unless a datastore), then space attributes for a match.

The purpose of this handler is to allow Space / Kapp / Form Attributes to be overridden by the lowest level specified.

=== Parameters
[Error Handling]
  Determine what to return if an error is encountered.  menu="Error Message,Raise Error"
[Start Context]
  The LOWEST context for which you want to search. If none found, the handler will continue to search through the end context.
  Should be one of Submission, Datastore Submission, Form, Datastore Form, Kapp, or Space.
[End Context]
  The HIGHEST context for which you want to search. If you specify Kapp here, no space attribtues will be searched since Space is
  higher than Kapp. Should be one of Submission, Datastore Submission, Form, Datastore Form, Kapp, or Space.
[Property to Find]
  The Property that the handler will search for (An Attribute name or Form Field Name)
[Backup Value]
  If no matches are found, the backup value will be returned
[Space Slug]
  The Slug of the Space to search. If blank, the Handlers Info Space Slug value will be used
[Kapp Slug]
  The Slug of the Kapp to search. (required if start context is "Kapp" or "Form")
[Form Slug]
  The Slug of the Form to search. (required if start context is "Form")
[Submission Id]
  The Submission ID to search (required if start/end context are "Submission")

=== Sample Configuration
Error Handling:    Error Message
Start Context:     Submission
End Context:       Space
Property To Find:  Notification Template
Backup Value:      Service Submitted
Space Slug:
Kapp Slug:
Form Slug:
Submission Id:     <%= @submission['Id']%>

=== Results
[Handler Error Message]
  Error message if an error was encountered and Error Handling is set to "Error Message".
[Matched Context]
   The Context for which the value was found (Space / Kapp / Form Attribute, Submission Values or the Backup Value)
[Value]
   The Matched Value Found and Returned

=== Detailed Description
Retrieves a submissions values, it's forms attribtues, kapps attributes, and spaces attributes.
Attributes and Values are returned as something like this:

Matched Context::  Kapp Attribute

Value::            Service Submitted
