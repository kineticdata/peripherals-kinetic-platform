## Kinetic Request CE Notification Template Send V4 (2022-07-01)

2018-05-09
 - Updated handler to retrieve data from CE Datastore. ** This handler is now
 only compatible with CE version 2.1 or later. **
 - Removed ability to record message as this functionality was not used

2018-12-21
 - Added ability to support attachments

2021-06-24
 - updated the regex for image cid.  The previous regex was greedy and took too much.

2021-07-01
 - added support for modern url to fetch attachments

2022-07-01
 - added support for defining TLS Method, required in specialized environments
 - added support for setting SMTP Open Timeout parameter
 - added support for defining which kapp/form slug containt he notification templates
 - removed never-used feature to save outbound emails in a Kinetic form
 - allows snippets to include dynamic/run-time replacements
 - enhance attachment function to allow attachments to be saved with a template so the same files can be sent every time, or to include attachments from the related submission.
