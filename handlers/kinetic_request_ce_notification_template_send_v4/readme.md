## Kinetic Request CE Notification Template Send
Sends an email notification using a template defined in Kinetic Request CE

### Parameters
[Error Handling]
  Determine what to return if an error is encountered.

[Space Slug]
  The slug of the Space in which notifications and messages should be retrieved from.

[Recipient Json Object]
  A JSON object representing a user and their preferences including Email, Notification Preferences, Language & Region.
    {
     "region":"test",
     "type":"user",
     "smtpaddress":{
        "to":"test@kineticdata.com",
        "cc":"test@kineticdata.com",
        "bcc":"test@kineticdata.com"
     },
     "language":"EN",
     "email notifications":"yes"
    }

[Notification Template Name]
  The name of a valid notification TEMPLATE that is Active in Kinetic Request CE.

[Replacement Values]
  A JSON Object of Values that should be replaced.

[Submission Id]
  The id of the related record that is use with attachments.

### Results

[Email Id]
  ID of the SMTP Message that was sent out.

[Message Id]
  ID of the message that was created in CE if record message parameter was set to true

## Details

Notifications (notifications) -- Console Page used for viewing, creating and modifying notification records.
Notification Data (notification-data) -- Stores notification templates / snippets
Notification Dates (notification-template-dates)  -- Stores date formats used used within your messages
