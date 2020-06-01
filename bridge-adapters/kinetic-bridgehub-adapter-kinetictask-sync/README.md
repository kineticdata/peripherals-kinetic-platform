# Kinetic Task Sync adapter
This adapter is used to create a synchronous experience when executing a Kinetic Task process.  This is accomplished using this adapter, a task process, and a datastore form.

## Overview

### High level overview
These are the steps of the synchronous process:
1. Client machine makes a bridge resource request of the Kinteic Task Sync adapter.
    * Configuration of the bridge and bridge models in Request and Bridgehub are required.
2. The adapter starts a task process.
    * The process that is started is passed to the adapter through the qualification mapping.
    * The adapter passes a Callback Id as an input to the process.
3. The task process writes a record to the kinetic-task-sync-log datastore form.
    * Task is responsible for populating the Callback Id field which is later used for lookup.
4. The adapter begins a polling process looking for a record with the Callback Id.
    * The polling process has a configurable timeout (default 5 seconds).
5. If the record is found the adapter will return its results.
    * If found the adpater will attempt to delete the record from the datastore.

### Potential Results
There are three potential results from the adapter.  The different results depended on whether the execution was a success, failure or there was a timeout. Which properties in the return object that get populated are dependent on the result of the execution.

|          | Return Status | Not Empty Return Properties  | Status of Record              |
|----------|---------------|------------------------------|-------------------------------|
| Success  | Complete      | results, status              | deleted (unless delete fails) |
| Time Out | Not Found     | callbackId, status           | in datastore                  |
| Failure  | Failed        | error, status                | unknown (depends on failure)  |

### The Task Processes Responsablity
* The process must create a submission in the kinetic-task-sync-log datastore form.
* The process must populate the provided callbackId to the Callback Id field on the datastore form.
* If there are results of the procss; they must be written to the Results field on the datastore form.

### Features of the Adapter
* On initialization of the adapter a check is made to see if kinetic-task-sync-log exists in the space.
* If kinetic-task-sync-log does not exist then the adapter will create it.
* A 5 second default timeout is provided, but can be overwritten in the Bridge Setup.
* If the timeout is set to 0 the adapter will start a task process and return without polling.
* A request to the adapter with just a callback id can be used to retrieve a record.  
* Once a record is found it will be returned and cleaned up (deleted from the datastore). 

## Configuration 

### Bridge Setup (done in Bridgehub)
For instructions on [setting up a bridge](https://community.kineticdata.com/platform/releases/bridgehub-install-guide#creating-a-new-bridge).

| Config Name          | Description                                                                  | Example Config Value                    |
|----------------------|------------------------------------------------------------------------------|-----------------------------------------|
| Task API Web Server  | The uri location for the Task Instance                                       | https://my-space.kinops.io/kinetic-task |
| Task API Username    | The username of the user that will act like a proxy to make request to Task  | wally@kineticdata.com                   |
| Task API Password    | The password for the user that will access Task                              | securePass                              |
| Core API Web Server  | The uri location for the Core Instance                                       | https://my-space.kinops.io              |
| Core API Username    | The username of the user that will act like a proxy to make request to Core  | wally.one@kineticdata.com               |
| Core API Password    | The password for the user that will access Core                              | securePass                              |
| Time Out Limit       | (Optional) Length of time, in seconds, that the polling process will execute | 10                                      |

### Bridge Configuration (done in Request CE)
This section covers bridge configuration models and mappings.   
All Kinetic Task Sync models: 
* Will have Result Type of single
* Can have the same 4 attributes defined (No additional properties are returned)
* Should have a Callback qualification

All Kinetic Task Sync mappings:
* Must use the kinetic-task-sync-log Structure

#### Example model
Name: Incident

Qualifications:

| Qualification   | Result Type | Parameters       |
|-----------------|-------------|------------------|
| Callback        | Single      | callbackId       |
| Create Incident | Single      | Title, Requester |

Attributes:
* Callback Id
* Error
* Results
* Status

#### Example mapping
Name: Incident
Structure: kinetic-task-sync-log

Attribute Mappings:

| Attribute | Mapped Value            |
|-----------|-------------------------|
| Callback  | ${fields('callbackId')} |
| Error     | ${fields('error')}      |
| Results   | ${fields('results')}    |
| Status    | ${fields('status')}     |

Qualification Mappings:

| Attribute       | Mapped Value                                                                             |
|-----------------|------------------------------------------------------------------------------------------|
| Callback        | callbackId=${parameters('callbackId')}                                                   |
| Create Incident | /Adhoc/Incident/Create?Title=${parameters('Title')}&Requester=${parameters('Requester')} |

**Note**: The Task Tree that the adpter will fire is configured in the model mappings.
* The Tree name pattern is /{Source}/{Group}/{Name}
* The qualification pattern is tree name followed by a question mark then parameters.  ex: /{Source}/{Group}/{Name}?payload=${parameters('payload')}
* When attempting to retrieve a record that exists only pass callbackId equal to the callback id.
