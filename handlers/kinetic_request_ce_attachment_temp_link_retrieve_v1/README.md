== Kinetic Request CE Attachment Temp Link Retrieve
Retrieves file attachment information for a submitted attachment field in
Kinetic Request CE. This information also contains the URL for each attachment so the
file can be downloaded from the file store.

=== Parameters
[Error Handling]
  Determine what to return if an error is encountered.
[Space Slug]
  The Space slug to be searched. If this value is not entered, the
  Space slug will default to the configured info value.
[Submission Id]
  The Id of the Submission to retrieve the attachment from
[Field Name]
  The name of the Field that contains the attachments.


=== Sample Configuration
Error Handling:         Error Message
Space Slug:
Submission Id:          65b39e7d-fdbb-11e5-a574-1f1230d968d5
Field Name:             Attachment

=== Results
[Handler Error Message]
  Error message if an error was encountered and Error Handling is set to "Error Message".
[Files]
  JSON info on the file, including the URL.

=== Detailed Description
Retrieves file attachment information for a submitted attachment field in
Kinetic Request CE. This information also contains the URL for each attachment so the
file can be downloaded from the file store. Urls are only good for ~5 seconds.

example results:
[
   {
      "contentType":"image/png",
      "name":"2016_PartialPlansMap-01.png",
      "size":175522,
      "url":"https://myserver/kinetic-filehub/filestores/kinetic-our-slug/2016/03/17/3fe2a934-21fb-4f5d-834b-51a492df5762?expiration=1458597108871&filename=2016_PartialPlansMap-01.png&key=ALM84LG&signature=9-5Ad87HpX5YaNkW2-DryI5SWSg"
   }
]
