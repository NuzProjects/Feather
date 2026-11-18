
<div align="center">

<img title="Quill" alt="Quill" height="180" src="landing.png">

**Sign and install apps on your iPhone or iPad with your own developer certificate. No computer needed, and it updates itself.**

[![Latest release](https://img.shields.io/github/v/release/NuzProjects/Quill?label=release&color=5B85F0)](https://github.com/NuzProjects/Quill/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/NuzProjects/Quill/total?label=downloads&color=5B85F0&cacheSeconds=3600)](https://github.com/NuzProjects/Quill/releases)
[![Stars](https://img.shields.io/github/stars/NuzProjects/Quill?style=flat&color=5B85F0)](https://github.com/NuzProjects/Quill/stargazers)
[![License](https://img.shields.io/github/license/NuzProjects/Quill?color=5B85F0)](https://github.com/NuzProjects/Quill/blob/main/LICENSE)

<p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="demo-dark.png"><source media="(prefers-color-scheme: light)" srcset="demo-light.png"><img alt="Quill" src="demo-light.png"></picture></p>


</div>

## Notice
**This is a fork of [Feather](https://github.com/claration/Feather) with several UX and signing improvements. I intend for this repository to receive all Quill updates, as well as any modifications I see fit.**
*__This Quill fork is under the GPL-3.0 license, and we do NOT collect any data from any user__*

## What's new in this fork

**Updates and signing**
- **In-app updates.** Quill downloads, signs and installs its own updates from Settings → Updates.
- **Get a Certificate.** Sign in with your Apple ID or use a trusted provider, right from Settings.
- **Certificate health.** Expiry and revocation alerts, plus an overview of days left, capabilities, devices and signed apps.
- **Safer, clearer signing.** Warnings before signing apps that need a newer iOS or are still App Store encrypted, plain-language errors, and time estimates.
- **Smaller apps and private installs.** Optionally strip the Apple Watch app and unused languages, and install through Quill's own helper and auto-renewing certificate.

**Apps and sources**
- **GitHub sources.** Add a GitHub repository and install IPAs straight from its releases.
- **Better sources.** Search apps across sources and see when each one last updated.
- **Working extensions.** Widgets and share sheets in signed apps get their own signing profile.

**Progress and widgets**
- **Live progress and Live Activities.** Signing, downloads and updates show as a floating panel, on the Lock Screen and in the Dynamic Island.
- **Home Screen widgets** for certificates and your library, in your accent color.

**Everything else**
- **Backup & Transfer, Navigator, and Developer Logs.** Back up and restore, customize tabs, and export logs or file a pre-filled bug report after a crash.
- **13 languages.**

Widgets and Live Activities need a certificate that covers all app IDs.

## Features

- User-friendly and clean UI.
- Sign and install applications.
- Supports [AltStore](https://faq.altstore.io/distribute-your-apps/make-a-source#apps) repositories.
- View detailed information about apps and your certificates.
- Configurable signing options mainly for modifying the app, such as appearance and allowing support for the Files app.
  - This includes patching apps for compatibility and Liquid Glass.
- Tweak support for advanced users, using [Ellekit](https://github.com/tealbathingsuit/ellekit) for injection. 
  - Supports injecting `.deb` and `.dylib` files.
- Actively maintained: always ensuring most apps get installed properly.
- No tracking or analytics, ensuring user privacy.
- Of course, open source and free.

## Download

Visit [releases](https://github.com/NuzProjects/Quill/releases) and get the latest `.ipa`. Once installed, Quill keeps itself up to date from Settings → Updates.

<a href="https://celloserenity.github.io/altdirect/?url=https://raw.githubusercontent.com/NuzProjects/Quill/refs/heads/main/source.json" target="_blank">
   <img src="https://github.com/CelloSerenity/altdirect/blob/main/assets/png/AltSource_Blue.png?raw=true" alt="Add AltSource" width="200">
</a>
<a href="https://github.com/NuzProjects/Quill/releases/latest/download/Feather.ipa" target="_blank">
   <img src="https://github.com/CelloSerenity/altdirect/blob/main/assets/png/Download_Blue.png?raw=true" alt="Download .ipa" width="200">
</a>

## Translating

Quill now supports translation; all localizations are in `Quill/Resources/Localizable.xcstrings`

To add a new language, open Xcode and use the interface to add/contribute to languages.

To properly contribute and test potentially new localizations, you can head over to the [contributing guide](./CONTRIBUTING.md).

## Acknowledgements

- [NuzFlameV2](https://github.com/NuzProjects) - Creator of the fork
- [Samara](https://github.com/claration) - The original creator
- [idevice](https://github.com/jkcoxson/idevice) - Backend for builds with this included, used for communication with `installd`.
- [*.backloop.dev](https://backloop.dev/) - localhost with public CA signed SSL certificate
- [Vapor](https://github.com/vapor/vapor) - A server-side Swift HTTP web framework.
- [Zsign](https://github.com/zhlynn/zsign) - Allows signing on-device, re-implemented to work on other platforms such as iOS.
- [LiveContainer](https://github.com/LiveContainer/LiveContainer) - Fixes/some help
- [Nuke](https://github.com/kean/Nuke) - Image caching.
- [Asspp](https://github.com/Lakr233/Asspp) - Some code for setting up the HTTP server.
- [plistserver](https://github.com/nekohaxx/plistserver) - Hosted on https://api.palera.in.

## License 

This project is licensed under the GPL-3.0 license. You can see the full details of the license [here](https://github.com/NuzProjects/Quill/blob/main/LICENSE). It's under this specific license because I wanted to make a project that is transparent to the user thats related to certificate paired sideloading, before this project there weren't any open source projects that filled in this gap.

By contributing to this project, you agree to license your code under the GPL-3.0 license as well (including agreeing to license exceptions), ensuring that your work, like all other contributions, remains freely accessible and open.
