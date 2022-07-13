Kinetic Request CE Submission DB Insert V1 (2017-04-12)
 * Initial version.  See README for details.

Kinetic Request CE Submission DB Insert V1.1 (2018-06-05)
* API Server Info Value changed to allow ${space} in the url for subdomain support
(ie. https://${space}.localhost:8080/kinetic)

Kinetic Request CE Submission DB Insert V1.2 (2020-10-29)
* Fixed bug for datastore submission deletions not working.
* Added info value for providing custom JDBC connection options

Kinetic Request CE Submission DB Insert V1.3 (2021-03-10)
* Fixed bug submissions not getting updated in the database.

Kinetic Request CE Submission DB Insert V1.4 (2022-04-01)
* PER-268 fixed unique key constraint bug.

Kinetic Request CE Submission DB Insert V1.4 (2022-07-03)
* KP-5616 fixed issues with limit field creation.  Limited fields were being created on the kapp > form table but the fields were normal text not limited varchar 4000 fields.

Kinetic Request CE Submission DB Insert V1.5 (2022-08-15)
* KD8W-104 added enable debug logging info value. Updated the SQL logger to log to engine logs. Removed submission value logging.
