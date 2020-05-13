== Kinetic Request CE Datastore Submission Search
Searches a Datastore Form for submissions and returns any matching submission objects in the
specified return format.

=== Parameters
[Error Handling]
  Determine what to return if an error is encountered.
[Space Slug]
  The space the submission is being retrieved from (defaults to info value if not provided).
[Datastore Form Slug]
  The slug of the Datastore Form to search for submissions in.
[Index]
  The index to use for the search.
[Query]
  The query that will be used to search the submissions. Ex: values[company]=Kinetic
[Limit]
  An integer representing the max results that the search can return.
[Return Type]
  The format that the results should be returned in.

=== Sample Configuration
Error Handling:         Error Message
Space Slug:
Datastore Form Slug:    cars
Index:                  values[Make]
Query:                  values[Make]="Ford"
Limit:                  100
Return Type:            JSON

=== Results
[Handler Error Message]
  Error message if an error was encountered and Error Handling is set to "Error Message".
[Count]
  The number of submissions that have been returned.
[Result]
  List of submissions that match the query --JSON,XML, or ID List


=== Detailed Description
Given a Request CE Space and Datastore Form, searches for submissions with a given query. The
query, index, and limit parameters are used to build the full query that will be passed to the
datastore submissions endpoint of the Request CE API (all requests will also add
?include=values,form,details to the query). Before being sent to the Request CE instance, the query
is escaped by running the URI.escape() command on the inputted query string. After all the
submissions that match the query have been returned, the handler formats it into one of three
possible output formats: a JSON string, an XML string, or an XML list of submission ids.

If ID List is selected as the Return Type, the output looks like:

<ids><id>f4cd6acf-e552-11e5-9c32-97bbc6bf7f84</id><id>bbc6bf7f-...</id></ids>

Note: The limit by default for submissions in 25, so if you want to retrieve more submissions than
that add a limit=n (where n is an integer representing the new limit) to the query string