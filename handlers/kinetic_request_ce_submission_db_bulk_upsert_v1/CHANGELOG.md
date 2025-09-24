Kinetic Reporting DB Upsert V1 (2021-06-12)
 * Initial version.  See README for details.

Update - v6 fieldKey hotfix (2024-12-10)
 * Hotfix added to increase fieldKey column size to accommodate for GUIDs in v6 being the default entry of the field

Kinetic Reporting DB Upsert V1.1 (2025-07-24)
* Updated to rework 1000 record limitation issues.  New strategy uses recursive searching using the updateAt values
* Updated to support datastores as a regular Kapp, vs a "special kapp"
    - Table naming had previously been app_<datastore-form-name>, and no common kapp-table was written for legacy Datastore forms
    - Added a new run-time input to support NOT writing submissions to a common kapp-table for a kapp-slug named 'datastore'
* Added support for kapp-defined fields for each kapp
* Corrected the page_size logic to properly use page-size inputs from the run-time hander parameters
