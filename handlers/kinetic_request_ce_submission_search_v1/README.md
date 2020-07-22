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
[Query]
  The query that will be used to search the submissions. Ex: values[company]=Kinetic
[Return Type]
  The format that the results should be returned in.

=== Sample Configuration
Error Handling:         Error Message
Space Slug:
Kapp Slug:              catalog
Form Slug:              test-form
Query:                  include=values&limit=100&q=values[Any Text] IN ("Testing","String")
Return Type:            JSON

=== Results
[Handler Error Message]
  Error message if an error was encountered and Error Handling is set to "Error Message".
[Count]
  The number of submissions that have been returned.
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