// Builds the install manifest for Feather's Semi Local installs, so app details
// stay on Feather's own site instead of a third-party plist server.
// GET /genPlist?bundleid=&name=&version=&fetchurl=

const escapeXML = (value) =>
  String(value).replace(/[<>&'"]/g, (c) => ({ "<": "&lt;", ">": "&gt;", "&": "&amp;", "'": "&apos;", '"': "&quot;" })[c]);

// Only manifests for IPAs served straight from a device by IP address (Feather's
// local server), never from a domain name, so this can't front installs for
// apps hosted on other websites. Carriers hand out all kinds of IPv4 addresses
// (private, CGNAT, 192.0.0.x on IPv6-only networks, sometimes public), so any
// IPv4 literal is accepted.
function isLocalPayload(raw) {
  let url;
  try {
    url = new URL(raw);
  } catch {
    return false;
  }
  if (url.protocol !== "http:" && url.protocol !== "https:") return false;
  if (!/\.ipa$/i.test(url.pathname)) return false;
  const host = url.hostname;
  if (host === "localhost" || host === "local.feather.madebynuz.dev") return true;
  const parts = host.split(".");
  return parts.length === 4 && parts.every((part) => /^\d{1,3}$/.test(part) && Number(part) <= 255);
}

export function onRequestGet({ request }) {
  const params = new URL(request.url).searchParams;
  const bundleID = params.get("bundleid") || "";
  const name = params.get("name") || "App";
  const version = params.get("version") || "1.0";
  const fetchURL = params.get("fetchurl") || "";

  if (!bundleID || bundleID.length > 255 || name.length > 255 || version.length > 64 || !isLocalPayload(fetchURL)) {
    return new Response("Bad request", { status: 400, headers: { "Cache-Control": "no-store" } });
  }

  const plist = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>items</key>
  <array>
    <dict>
      <key>assets</key>
      <array>
        <dict>
          <key>kind</key>
          <string>software-package</string>
          <key>url</key>
          <string>${escapeXML(fetchURL)}</string>
        </dict>
      </array>
      <key>metadata</key>
      <dict>
        <key>bundle-identifier</key>
        <string>${escapeXML(bundleID)}</string>
        <key>bundle-version</key>
        <string>${escapeXML(version)}</string>
        <key>kind</key>
        <string>software</string>
        <key>title</key>
        <string>${escapeXML(name)}</string>
      </dict>
    </dict>
  </array>
</dict>
</plist>
`;
  return new Response(plist, {
    headers: {
      "Content-Type": "application/xml; charset=utf-8",
      "Cache-Control": "no-store",
      "X-Robots-Tag": "noindex",
    },
  });
}
