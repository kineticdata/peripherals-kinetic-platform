## Kinetic Reporting Submission DB Upsert
Using input submission query information, this handler creates/updates records
in an external database for the submissions retrieved from Core.

### Parameters
TODO

### Sample Configuration
TODO

### Results
TODO

### Detailed Description
After connecting to the specified database using
the inputted info values (JDBC database id further explained below), the database
will be checked to see if a table exists for the submissions form. If it does not
exist, the table will be created. If it does exist but there are differences in
the form inputs, columns will be added to the table as needed. After the table
is all squared away, the submission will then be added to the table. Below is
how the submission will be formatted in the table.

### Schema information

**TABLE NAME**:

    _kapp-slug_form-slug_, or _truncate(kapp-slug_form-slug_, max_db_identity_size - 5 characters for _crc16)_crc16(kapp-slug_form-slug) if the concatenation of the kapp slug and form slug exceeds max_db_identity_size.
    max_db_identity_size is the max size a table name or column name can be in a given SQL Database engine (currently for Oracle this is 30 characters, PostgreSQL 64, and MSSQL 128)
    (ie. For an Oracle database and kappSlug=catalog and formSlug=simple-input, the table name is catalog_simple-input)
    (ie. For an Oracle database and kappSlug=catalog and formSlug=this-is-a-test-form-that-is-very-long, the table name is catalog_this-is-a-test-fo_fd03)

**COLUMNS**:

    Each form table will have the c\_anonymous,c\_closedAt,c\_closedBy,c\_createdAt,c\_createdBy,c\_id(submission id), c\_originId,c\_parentId,c\_updatedAt,c\_updatedBy,c\_submittedAt,c\_submittedBy fields.
    Additionally there will be a column for each value on the form in the form of (u|l)\_field name, or (u|l)\_field name\_crc16(field name) if the field name is longer than the max supported column name length supported by the database.

    The u_ prefix stands for value unlimited and the l_ prefix stand for value limited. Both the unlimited length version of a value and a limited length, truncated at 4000 characters, is saved to the database.
    This is done to allow report writers to decide which columns to use in a report. Using the l\_ columns will be allow for potential joining/aggregating, but sometimes 4000 characters doesn't cut it in a report.


**ORACLE COLUMN NAME EXAMPLES (30 character max limit):**

    A field name of First Value will be a database column of:
        u_First Value
    &
        l_First Value

    A field name of "Please enter the first name of the requestor" will be a database column of:
        u_Please enter the first _ef90
    &
        l_Please enter the first _ef90


### Test cases

(x) - MSSQL Support (2012 tested)  
(x) - PostgreSQL Support (9.5 tested)  
(x) - Support saving unlimited length answers.  
(x) - Support saving multi-byte unicode characters.  
(x) - Support record upserting for kapp table rows and individual form table rows.  
(x) - Support table column additions on form changes (new submissions with new fields).  
(x) - Support field names with spaces  
(x) - Support single dashes (-) in table names for slugs  
(x) - Deleting a submission field value pushes null to the database for that field (for instances where a value is deleted)  
(x) - Guaranteed upsert order (e.g. UPDATE form SET x = 'y' WHERE "c_updatedAt" < ?) ? = submission updatedAt  
(x) - SQL Injection tested

## Important Notes
An **Overwrite** of the kinetic_request_ce_submission_db_upsert_v1 handler requires a restart of the Tomcat server hosting the Task web application.
