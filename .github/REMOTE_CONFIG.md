# Remote settings

Feather downloads [`remote-config.json`](../remote-config.json) from `main` when it opens (and at most every 15 minutes after). Editing that file changes the app for everyone without a new build. GitHub can take up to about 5 minutes to serve the new version.

Every field is optional. Leave one out (or set it to `null`) and Feather uses what's built into the app. If the file has a mistake, Feather keeps using the last good copy.

| Field | What it does |
| --- | --- |
| `announcement` | An alert shown once per `id`. Change the `id` to show a new one. `buttonTitle` and `url` add a button that opens a link. `maxVersion` (like `"1.2.4"`) limits it to that version and older. |
| `certificateProviders` | The list in **Get a Certificate**. `icon` is an SF Symbol name. `official: true` puts it under **Official**. |
| `featuredSources` | The **Featured** list in **Add Source**. |
| `plistServer` | The plist server used by Semi Local installs. Only change this if the default stops working. |
| `flags` | On/off switches for features that already exist in the app. |

Example announcement:

```json
"announcement": {
  "id": "revoke-2026-11",
  "title": "Certificates Revoked",
  "message": "Apple revoked many certificates today. Check yours in Settings.",
  "buttonTitle": "Learn More",
  "url": "https://github.com/NuzProjects/Feather/discussions"
}
```

Check the JSON is valid before saving (for example with jsonlint.com). Code changes still need a new build.
