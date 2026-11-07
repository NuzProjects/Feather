## Update 1.3.3

**New Features:**
* Fully Local works again: it uses Feather's own certificate for local.feather.madebynuz.dev, which renews automatically and is replaced if it's ever revoked
* Semi Local uses Feather's own install helper, so app names and bundle IDs aren't sent to a third-party service

**Bug Fixes:**
* Feather asks before a link adds a certificate
* Certificates are only exported to other apps, never to websites, and the prompt shows which app is asking
* When it doesn't need your network, Feather's install server only listens on your device
* If Fully Local can't start an install, Feather offers to switch to Semi Local instead of waiting on Ready
* The install sheet has a bigger app icon and no extra box inside it
