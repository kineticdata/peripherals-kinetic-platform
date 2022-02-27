# Kinetic Core Bridgehub Adapter
A Kinetic Bridgehub adapter for the Kinetic Request: Core Edition platform.
This adapter works with Core 2.4+

## Configuration Values
| Name                    | Description | Example Value |
| :---------------------- | :------------------------- | :------------------------- |
| Username                | The username that will be used to access the Kinetic Core information | user@acme.com |
| Password                | The password that is associated with the username | secret-password |
| Kinetic Core Space Url  | The url of the Kinetic Core instance up to and including the space that up want to be retrieving the data from | https://localhost:8080/kinetic/space-slug |

## Supported Structures
| Name | Description |
| :---------------------- | :------------------------- |
| Space | Get space |
| Datastore Forms | Get datastore forms |
| Datastore Submissions | Get a datastore submission.  id=submission_slug required in qualification mapping |
| Datastroe Submissions > FORM_SLUG | Get datastore submissions for a form |
| Kapps | Get kapps |
| Forms > KAPP_SLUG | Get forms for a kapp |
| Submissions | Get a submission. id=submission_slug required in qualification mapping |
| Submissions > KAPP_SLUG | Get submissions for a kapp |
| Submissions > KAPP_SLUG > FORM_SLUG | Get submissions for a kapp and form |
| Teams | Get teams |
| Users | Get Users |

## Fields
Fields that will be returned with the record.  If no fields are provided then all fields will be
returned.

## Qualification (Query)
Supports all queries that Core api supports for the given context.  An id parameter is required for datastore submission and kapp submission lookups.

### Example Qualifications
* Get a form and its fields: `q=slug="${parameters("Form Slug")}"&include=fields`
* Get teams by their parent name: `q=parentName="${parameters('Parent')}"`
* Get datastore submissions by status and user: `index=values[Status],values[Assigned Individual]&q=values[Status]="${parameters('Status')}" AND values[Assigned Individual]="${parameters('Username')}"`

## Importent notes
* Ampersands in the qualification mapping that are not intended to split parameters must be encoded. ex: `index=values[foo],values[bar]&q=values[foo]="Fizz %26 Buzz" AND values[bar]=""` 
* Ampersand can be in values represented by `${parameter(...)}`. ex: `index=values[foo],values[bar]&q=values[foo]="${parameter("foo")}" AND values[bar]=""` where `${parameter("foo")}` == Fizz & Buzz
* This adapter can not currently be used with the Kinetic Calendar.