== Kinetic Request CE Submission Search
Searches a kapp or form for submissions and returns any matching submission objects in the
specified return format.

=== Parameters
[Error Handling]
  Determine what to return if an error is encountered.
[Space Slug]
  The space the submission is being retrieved from (defaults to info value if not provided).
[Kapp Slug]
  The slug of the Kapp to search for submissions in
[Form Slug]
  The slug of the Form to search for submissions in
[Include]
  Comma-separated list of properties to include in the response. Options include 'details', 'activities', 'children', 'descendants', 'form', 'origin', 'parent', 'type', 'values', 'values.raw', and 'values[FIELD NAME]'
[Core State]
  Searches for submissions that have a core state that matches this parameter. Options
  are 'Draft', 'Submitted', 'Closed'.  If no value is provided, the results will
  contain submissions in all core states.
[Timeline]
  Date property to search by. Options are 'createdAt','submittedAt','updatedAt', and
  'closedAt'. The default value is 'createdAt'.
[Direction]
  Result Set sorting direction. Options are 'ASC' and 'DESC' The default value is
  descending (DESC).
[Start]
  Start date/time of the timeline. This value should be used to both refine and limit
  the search results. Format: yyyy-MM-ddTHH:mm:ssZ
[End]
  End date/time of the timeline. This value should be used to both refine and limit
  the search results. Format: yyyy-MM-ddTHH:mm:ssZ
[Limit]
  Limit the number of results returned. If not provided, the server will limit the
  results to 25 submissions.  Maximum value 1000.
[Query]
  The query that will be used to search the submissions. Ex: values[company]=Kinetic
[Page Token]
  The value to use as the offset for the page of submissions to return. The submission that
  matches this value will not be included in the results.
[Return Type]
  The format that the results should be returned in.

=== Sample Configuration
Error Handling:         Error Message
Space Slug:
Kapp Slug:              catalog
Form Slug:              test-form
Include:
Core State:
Timeline:
Direction:
Start:
End:
Limit:                  1000
Query:                  include=values&limit=100&q=values[Any Text] IN ("Testing","String")
Page Token:             70b37e5f-d64c-11e8-bbc0-ebb51a7fa935
Return Type:            JSON

=== Results
[Handler Error Message]
  Error message if an error was encountered and Error Handling is set to "Error Message".
[Count]
  The number of submissions that have been returned.
[Next Page Token]
  The ID of the last submission retrieved by the API if the Limit input is reached.  This can be
  used in a subsequent call to continue retrieve results.
[Result]
  List of submissions that match the query --JSON,XML, or ID List


=== Detailed Description
Given a Request CE Space, Kapp, and optional Form, searches for submissions with a given query. The
query parameter allows anything that can be passed into the query parameter in the /submissions
endpoint of the Request CE API (including the limit= and q= parameters). Before being sent to the
Request CE instance, the query is escaped by running the URI.escape() command on the inputted query
string. After all the submissions that match the query have been returned, the handler formats it
into one of three possible output formats: a JSON string, an XML string, or an XML list of
submission ids.

If ID List is selected as the Return Type, the output looks like:

<ids><id>f4cd6acf-e552-11e5-9c32-97bbc6bf7f84</id><id>bbc6bf7f-...</id></ids>

Note: The limit by default for submissions in 25, so if you want to retrieve more submissions than
that add a limit=n (where n is an integer representing the new limit) to the query string
