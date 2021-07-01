  == Kinetic Request CE Attachment Create
  Creates a plaintext attachment and uploads it to a Kinetic Request CE Form.

=== Parameters
[Error Handling]
  Determine what to return if an error is encountered.
[Space Slug]
  The space to upload the newly created file to.
[Kapp Slug]
  The kapp to upload the newly created file to.
[Form Slug]
  The form to upload the newly created file to.
[Filename]
  The name of the file to create.
[File Content]
  The content for the file being created.
[Input Encoding]
  Tell the handler if the input was already encoded for Base64.

=== Sample Configuration
Error Handling:         Raise Error
Space Slug:             catalog
Kapp Slug:              acme
Form Slug:              attachment-form
Filename:               hello-world.txt
File Content:           Hello World! This is a sample file!
Input Encoding:         Plain

=== Results
[Handler Error Message]
  Error message if an error was encountered and Error Handling is set to "Error Message".
[Files]
  The JSON response that is returned from Kinetic Request CE after uploading a
  file. This will the text that should be submitted as an attachment question
  value for a Submission Create call.

=== Detailed Description
This handler create a plaintext attachment and uploads it to a Kinetic Request
CE form. The file is created using the Filename and File Content input parameters
and is then passed to the specified form using the Content Type of text/plain.
If the file is successfully uploaded, the handler will return a JSON file string
that will be most likely used in conjunction with the Kinetic Request CE
Submission Create handler. The JSON Files response should be passed directly to
the Sumbission Create call as a part of the values object for the attachment
question on the form. An example of using this handlers result is below (where
"Upload Attachment" is the label for the attachment field on the form).

{"Upload Attachment" : <%=@results['kinetic_request_ce_create_attachment_v1']['Files']%>}