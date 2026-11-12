## Update 1.3.5 Beta 7

**New Features:**
* Lock Screen certificate widgets: a days-left gauge, a larger card with the expiry date, and a one-line version
* Feather warns before installing an app signed with an expired or revoked certificate, and offers to re-sign it
* Signing keeps going when you leave Feather, and you get a notification when it finishes

**Security:**
* A malicious IPA or .deb tweak can no longer write files outside its own unpack folder* Links that add a source now ask you first instead of adding it silently
* Removed a leftover exception that allowed one website to load over plain HTTP
