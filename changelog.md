Kinetic Platform [handlers] (2025-02-06)
  * [kinetic_request_ce_submission_db_bulk_upsert_v1]
    * Added hotfix code to change fieldKey to 256 if length is 8
  * [kinetic_request_ce_submission_db_insert_v1]
    * Added hotfix code to change fieldKey to 256 if length is 8
Kinetic Platform [handlers] (2021-12-16)
  * [kinetic_request_ce_attachment_create_v2]
    * Initial Version of v2
    * Updated code to retrieve the attachment using authentication
  
Kinetic Platform [bridge-adapter] (2019-11-25)
  * [kinetic-bridge-adapter-kinetic-platform]
    * initial commit.

Kinetic Platform [bridge-adapter] (2020-01-05)
  * [kinetic_agent_handler_execute_v1]
    * added handler to the project.

Kinetic Platform [bridge-adapter] (2020-07-22)
  * [kinetic-bridgehub-adapter-kinetic-platform]
    * modified error handling.
Kinetic Platform [handlers] (2020-07-22)
  * [kinetic_request_ce_submission_search_v1]
    * modified error handling.
  * [kinetic_request_ce_submission_search_v2]
    * modified error handling.
  * [kinetic_request_ce_submission_update_v1]
    * modified error handling.

Kinetic Platform [bridge-adapter] (2020-10-26)
  * [kinetic-bridgehub-adapter-kinetic-platform]
    * updated log4j and junit dependencies

Kinetic Platform [bridge-adapter] (2021-01-21)
  * [kinetic-bridgehub-adapter-kinetic-platform]
    * updated pom for platform adapter to new version number
    * updated readme to have qualification mapping examples
  * [kinetic_request_ce_submission_db_insert_v1]
    * Fix datastore submission delete. Addd custom JDBC connection options

Kinetic Platform [handlers] (2021-04-29)
  * [kinetic_request_ce_notification_template_build_v1]
    * initial commit.

Kinetic Platform [handlers] (2021-06-24)
  * [kinetic_request_ce_notification_template_send_v3]
    * initial commit and modification.

Kinetic Platform [handlers] (2021-06-27)
  * [kinetic_request_ce_submission_create_v2]
    * added support for base 64 input

Kinetic Platform [handlers] (2021-07-01)
  * [kinetic_request_ce_notification_template_send_v3]
    * added support for auth to fetch files from filehub.

Kinetic Platform [bridge-adapter] (2021-09-08)
  * [kinetic-bridgehub-adapter-kinetic-platform]
    * Fixed ampersands in parameters issue KP-3631.

Kinetic Platform [handlers] (2021-10-14)
  * [kinetic_request_ce_notification_template_send_v3]
    * fixed regression caused in previous update.  

Kinetic Platform [handlers] (2021-10-30)
  * [kinetic_request_ce_attachment_copy_remote_server_v1]
    * initial commit.

Kinetic Platform [handlers] (2022-04-01)
  * [kinetic_request_ce_submission_db_insert_v1]
    * PER-268 fixed unique key constraint bug.

Kinetic Platform [handlers] (2022-07-13)
  * [kinetic_request_ce_submission_db_insert_v1]
    * KP-5616 fixed issues with limit field creation.

Kinetic Platform [handlers (2022-08-15)
  * [kinetic_request_ce_submission_db_insert_v1]
    * KD8W-104 added info value to db insert handler.

Kinetic Platform [bridge-adapter] (2022-12-23)
  * [kinetic-bridgehub-adapter-kinetic-platform]
   * KP-5895 added webApi search/retrieve functionality (space and kapp)

Kinetic Platform [handlers] (2023-09-06)
  * [kinetic_request_ce_submission_db_insert_v1]
   * bug fixes to create kapp table if it doesn't exist
