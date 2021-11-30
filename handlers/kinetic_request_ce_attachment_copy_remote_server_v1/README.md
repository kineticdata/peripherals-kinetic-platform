== Kinetic Request CE Attachment Copy Remote Server
    This handler is used to copy an attachment from one submission to another on different servers.

=== Parameters
    [Error Handling]
        How to handle error conditions in the handler: raise the error, or return error message
    [Source Space Slug]
        Slug of the Space where the handler should be imported
    [Source Kapp Slug]
        The Kapp the containing form is in.
    [Source Form Slug]
        The Form containing the attachment.
    [Source Submission Id]
        Submission Id that contains the attached file to copy.
    [Source Form Field Name]
        Name of the file attachment field on the Kinetic Request CE form to copy from.
    [Destination Space Slug]
        Slug of the Space where the handler should be imported.
    [Destination Kapp Slug]
        The Kapp the receiving form is in.
    [Destination Form Slug]
        The Form receiving the attachment.
    [Destination Submission Id]
        Submission Id that contains the attached file to copy to.
    [Destination Form Field Name]
        Name of the file attachment field on the Kinetic Request CE form to copy from.

=== Results
[Handler Error Message]
  Error message if an error was encountered and Error Handling is set to "Error Message".
[Files]
  Information on the files that were copied.
[Space Slug]
  The space slug that was used.

==== Sample Configuration
Error Handling:             Raise Error
source_space_slug:  
source_kapp_slug:           public
source_form_slug:           request    
source_field_name:          Confidentiality Statement Form
source_submission_id:       e5d08566-4d60-11ec-b100-99b36abf0f1e
destination_space_slug:
destination_kapp_slug:      queue
destination_form_slug:      access-request-signature-verification   
destination_field_name:     Signed Document
destination_submission_id:  a5da180d-4d62-11ec-b963-a54dee5dbbd6

=== Detailed Description
This handler uses the Kinetic Request CE REST API to retrieve the file the user submitted in one
submission to download it and upload a copy into another specified submission on another server. Note: this is
particularly helpful when passing attachments from service to queue task or from queue task to
queue task.