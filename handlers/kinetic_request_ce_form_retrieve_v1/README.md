== Kinetic Core Form Retrieve
Retrieves a form record in Kinetic Request CE for the specified space.

=== Parameters
[Error Handling]
  Determine what to return if an error is encountered.  menu="Error Message,Raise Error"
[Space Slug]
  The Space slug to be searched. If this value is not entered, the
  Space slug will default to the one configured in info values.
[Kapp Slug]
  The slug of the Kapp the form is for.
[FormSlug]
  The slug of the Form that is being retrieved.

=== Sample Configuration
Error Handling:         Error Message
Space Slug:
Kapp Slug:              catalog
Form Slug:              sample-form

=== Results
[Handler Error Message]
  Error message if an error was encountered and Error Handling is set to "Error Message".
[Name]
  Name of the form.
[Slug]
  Slug of the form being retrieved.
[Description]
  Description of form.
[CreatedAt]
  When the form was created.
[CreatedBy]
  Who created the form.
[UpdatedAt]
  When the form was updated.
[UpdatedBy]
  Who updated the form.
[Notes]
  Notes on this form.
[Secure]
  Is the form secure?
[Attributes]
  A json structured list of attributes of the form.
[Fields]
  A json structured list of fields for the form.

=== Detailed Description
This handler retrieves a form.

Note that while the value of the attributes are included, the value of the fields is not.
Example results for attribute and fields:

Attributes
[{"name"=>"Custom Workflow on Submitted", "values"=>["True"]}, {"name"=>"Icon", "values"=>["fa-dollar"]},
{"name"=>"Owning Team", "values"=>["Admin", "Sales", "Execution", "Ops"]},
{"name"=>"Task Assignee Team", "values"=>["Execution"]}]
Fields
["Advertiser","Advertiser SF Id","Agency","Agency SF Id","Ad Budget","IO Number","Campaign Start Date",
"Campaign End Date","Date Order is Received","Order Revision Number","Advertiser Rep","Agency Rep",
"Opportunity ID","Index","Issue Date","Segment Name","Segment Start Date","Segment End Date","SF Units",
"Units","Target","Cost of Goods Sold","segmentTableJSON","Requested For","Requested For Display Name",
"Requested By","Requested By Display Name","Discussion Id","Observing Teams","Observing Individuals","Status"]