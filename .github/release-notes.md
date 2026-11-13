## Update 1.3.5 Beta 9

**New Features:**
* Sign in with a free Apple ID: no certificate needed. Go to Settings → Certificates → + → Sign In with Apple ID, and Feather makes a free development certificate and signs each app with its own profile from Apple
* Free Apple ID limits still apply: signed apps last 7 days, up to 3 can be installed at once, and up to 10 new apps can be added per week. Apps get a bundle ID ending in your team ID
* Find My UDID fills in your device's UDID for the Apple ID sign-in: allow the profile download, install it in Settings, and you're brought straight back to Feather
* The Apple ID sign-in now opens inside the same sheet as New Certificate
* Two-factor codes are asked for when Apple needs them, and your Apple ID details stay in this device's Keychain
* Lock Screen certificate widgets: a days-left gauge, a larger card with the expiry date, and a one-line version
* Feather warns before installing an app signed with an expired or revoked certificate, and offers to re-sign it
* Signing keeps going when you leave Feather, and you get a notification when it finishes

**Security:**
* A malicious IPA or .deb tweak can no longer write files outside its own unpack folder
* Links that add a source now ask you first instead of adding it silently
* Removed a leftover exception that allowed one website to load over plain HTTP
