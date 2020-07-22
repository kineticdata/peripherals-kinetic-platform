Kinetic Request CE Submission Update V1.2.2 (2020-07-22)
* Modified error handling.

Kinetic Request CE Submission Update V1.2.1 (2019-11-22)
* fixed issue with auto retries.  The condition that checks if a retry is necessary due to an update collision is now
backwards and future compatible. 

Kinetic Request CE Submission Update V1.2 (2018-08-29)
* Added functionality to retry the handler if a stale object exception occurs during submission update.
(ie. If updating the submission within a loop, there is a chance that two updates will occur at the same time. This will retry up to 10 times before returning an error or throwing an exception.)

Kinetic Request CE Submission Update V1.1 (2018-05-25)
* API Server Info Value changed to allow ${space} in the url for subdomain support
(ie. https://${space}.localhost:8080/kinetic)

Kinetic Request CE Submission Update V1 (2015-04-24)
 * Initial version.  See README for details.
