## Update 1.2.4

**New Features:**
* Get a Certificate in Settings when you don't have one, with official and third-party providers and a shortcut to import
* Tapping an app in a source opens its page on iOS 16

**Bug Fixes:**
* Fixed a crash when installing or exporting apps that have no version or name
* Fixed a crash when signing an app with a missing or broken Info.plist
* Fixed crashes when reading some .deb tweaks, and .deb files from more tools are read correctly
* Fixed a possible crash when the install server's port was busy, and installs now stop with a clear error if the server can't start
* Install progress no longer checks 1,000 times a second, saving battery during installs
* Fixed crashes from alerts or the share sheet appearing while Feather is in the background
* Failed downloads now show why, and server error pages are no longer imported as apps
* Downloads keep going in the background on iOS 26 again
* Importing a certificate shows an error instead of closing silently, and no longer writes to the database off the main thread
* Featured sources no longer go missing, Import explains an empty clipboard, and invalid source URLs show a message
* Sources that can't load show a message instead of spinning forever
* Retrying a sign keeps your .dylib tweaks
* Imports work right after Reset without relaunching
* Lists update immediately after Reset
* Exported certificates with special characters in the password reach other apps correctly
* Changing a bundle ID also updates watch extension identifiers
* Clearer errors for damaged IPAs and unreadable provisioning profiles
