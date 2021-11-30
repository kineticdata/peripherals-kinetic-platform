== Kinetic Request CE Attachment Copy
    This handler is used to copy an attachment from one submission to another.

=== Parameters
    [Error Handling]
        How to handle error conditions in the handler: raise the error, or return error message
    [Space Slug]
        Slug of the Space where the handler should be imported
    [From Submission Id]
        Submission Id that contains the attached file to copy.
    [From Form Field Name]
        Name of the file attachment field on the Kinetic Request CE form to copy from
    [To Kapp Slug]
        The Kapp the receiving form is in
    [To Form Slug]
        The Form receiving the attachment.
    [To Submission Id]
        Submission Id that contains the attached file to copy to
    [To Form Field Name]
        Name of the file attachment field on the Kinetic Request CE form to copy to

=== Results
[Handler Error Message]
  Error message if an error was encountered and Error Handling is set to "Error Message".
[Files]
  Information on the files that were copied.
[Space Slug]
  The space slug that was used.

==== Sample Configuration
Error Handling:          Raise Error
Space Slug:
From Submission Id:      69825435-2b7b-11e7-983f-0748e4ca60e1
From Form Field Name:    File to Review
To Kapp Slug:            services
To Form Slug:            file-review
To Submission Id:        2a003fbf-2b8a-11e7-983f-c7d5681811fa
To Form Field Name:      File to Review

=== Detailed Description
This handler uses the Kinetic Request CE REST API to retrieve the file the user submitted in one
submission to download it and upload a copy into another specified submission. Note: this is
particularly helpful when passing attachments from service to queue task or from queue task to
queue task.