// Finds a device's UDID for Feather's Apple ID sign-in, the same way UDID websites do.
// GET /udid serves a Profile Service profile. After it's installed, iOS posts the device's
// UDID here and Settings is sent straight back to Feather with it. Nothing is stored.

const noStore = { "Cache-Control": "no-store" };

const escapeHTML = (value) =>
  String(value).replace(/[<>&'"]/g, (c) => ({ "<": "&lt;", ">": "&gt;", "&": "&amp;", "'": "&#39;", '"': "&quot;" })[c]);

const isUDID = (value) => /^[0-9A-Fa-f-]{24,40}$/.test(value || "");

function profile(origin) {
  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>PayloadContent</key>
  <dict>
    <key>URL</key>
    <string>${origin}/udid</string>
    <key>DeviceAttributes</key>
    <array>
      <string>UDID</string>
      <string>PRODUCT</string>
    </array>
  </dict>
  <key>PayloadOrganization</key>
  <string>Feather</string>
  <key>PayloadDisplayName</key>
  <string>Feather Device ID</string>
  <key>PayloadDescription</key>
  <string>Sends this device's UDID back to Feather so it can register your device with your Apple ID. Nothing stays installed.</string>
  <key>PayloadIdentifier</key>
  <string>dev.madebynuz.feather.udid</string>
  <key>PayloadUUID</key>
  <string>6C3A1E0B-4F8D-4C2A-9B7E-2D5F1A8C3E91</string>
  <key>PayloadVersion</key>
  <integer>1</integer>
  <key>PayloadType</key>
  <string>Profile Service</string>
</dict>
</plist>
`;
}

function donePage(udid) {
  const appURL = `feather://udid?value=${encodeURIComponent(udid)}`;
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>Feather UDID</title>
<style>
  :root { color-scheme: light dark; --bg: #f2f2f7; --card: #fff; --text: #1c1c1e; --muted: #6c6c70; --accent: #848ef9; }
  @media (prefers-color-scheme: dark) { :root { --bg: #000; --card: #1c1c1e; --text: #f2f2f7; --muted: #98989f; } }
  body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: var(--bg); color: var(--text); font: 17px -apple-system, system-ui, sans-serif; }
  main { width: min(420px, calc(100% - 32px)); background: var(--card); border-radius: 22px; padding: 28px 22px; text-align: center; }
  h1 { font-size: 22px; margin: 0 0 8px; }
  p { color: var(--muted); margin: 0 0 18px; line-height: 1.4; }
  code { display: block; font: 13px ui-monospace, Menlo, monospace; word-break: break-all; background: var(--bg); padding: 12px; border-radius: 12px; margin-bottom: 18px; user-select: all; }
  a { display: block; background: var(--accent); color: #fff; text-decoration: none; font-weight: 600; padding: 14px; border-radius: 14px; }
</style>
</head>
<body>
<main>
  <h1>UDID Found</h1>
  <p>Head back to Feather to finish signing in.</p>
  <code>${escapeHTML(udid)}</code>
  <a href="${escapeHTML(appURL)}">Open Feather</a>
</main>
<script>setTimeout(function () { location.href = ${JSON.stringify(appURL)}; }, 300);</script>
</body>
</html>
`;
}

export function onRequestGet({ request }) {
  const url = new URL(request.url);
  const udid = url.searchParams.get("udid");
  if (udid !== null) {
    if (!isUDID(udid)) return new Response("Bad request", { status: 400, headers: noStore });
    return new Response(donePage(udid), { headers: { ...noStore, "Content-Type": "text/html; charset=utf-8" } });
  }
  return new Response(profile(url.origin), {
    headers: {
      ...noStore,
      "Content-Type": "application/x-apple-aspen-config",
      "Content-Disposition": 'attachment; filename="Feather-UDID.mobileconfig"',
    },
  });
}

export async function onRequestPost({ request }) {
  const body = new TextDecoder("utf-8", { fatal: false }).decode(await request.arrayBuffer());
  const match = body.match(/<key>UDID<\/key>\s*<string>([0-9A-Fa-f-]{24,40})<\/string>/);
  if (!match) return new Response("Bad request", { status: 400, headers: noStore });
  return new Response(null, {
    status: 301,
    headers: { ...noStore, Location: `feather://udid?value=${encodeURIComponent(match[1])}` },
  });
}
