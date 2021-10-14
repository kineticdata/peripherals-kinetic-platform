## Kinetic Request CE Notification Template Send V3 (2017-02-10)

2018-05-09
 - Updated handler to retrieve data from CE Datastore. ** This handler is now
 only compatible with CE version 2.1 or later. **
 - Removed ability to record message as this functionality was not used

2018-12-21
 - Added ability to support attachments

2021-06-24
 - updated the regex for image cid.  The previous regex was greedy and took too much.

2021-07-01
 - added support for modern url to fetch attachments.

2021-10-14
 - fixed regression that was caused in previous commit.