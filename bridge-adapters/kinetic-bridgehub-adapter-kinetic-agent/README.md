# Kinetic Agent Bridge Adapter
This Rest based bridge adapter is designed to make requests to the Kinetic Agent.  This is required if the Core version is pre 5.  This is due to the fact that the Agent doesn't support Key/Secret, but requires auth.  Basic auth is the strategy to use.
The adapter will forward the bridge request onto the Agent.
___
## Adapter Configurations
Space | The space defined when the bridge was created.
Slug | The slug of the bridge defined when created.
Username | Username of user used to log into the Agent consoles.
Password | The users password.
AGENT URL | Web address to AR System server. (ex: https://foo.bar.com/kinetic-agent)
___
## Supported structures
The adapter forwards the structure onto the Agent. 
___
