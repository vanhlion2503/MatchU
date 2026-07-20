# Post sharing deployment

The app shares canonical links in the form
`https://matchu-5bd75.web.app/p/{postId}`. Override the base URL for another
environment with `--dart-define=MATCHU_SHARE_BASE_URL=https://your-domain`.
When using another domain, update the matching hosts in AndroidManifest.xml,
Runner.entitlements, Firebase Hosting, and the association files as well.

## Firebase Hosting

Deploy the landing page and Android association file with:

```sh
firebase deploy --only hosting
```

The checked-in `assetlinks.json` matches the current Android application ID and
debug signing key. Before publishing to Google Play, replace the application ID
and add the Play App Signing SHA-256 fingerprint.

## iOS Universal Links

`Runner.entitlements` already enables `matchu-5bd75.web.app`. To finish domain
verification, create `hosting/.well-known/apple-app-site-association` after the
Apple Team ID and production Bundle ID are assigned:

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["APPLE_TEAM_ID.PRODUCTION_BUNDLE_ID"],
        "components": [{ "/": "/p/*" }]
      }
    ]
  }
}
```

Until those production credentials exist, the landing page's `matchu://`
button remains a working installed-app fallback on both Android and iOS.
