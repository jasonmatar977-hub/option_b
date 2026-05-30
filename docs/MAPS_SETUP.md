# OMW Maps Setup

Google Maps is disabled by default. The app renders a static "Map preview"
placeholder until you pass the compile-time flags below.

## Enabling Google Maps (dev / web)

```bash
flutter run -d chrome \
  --dart-define=OMW_USE_GOOGLE_MAPS=true \
  --dart-define=OMW_GOOGLE_MAPS_API_KEY=YOUR_KEY_HERE
```

## Enabling Google Maps (web release build)

```bash
flutter build web --release \
  --base-href=/option_b/ \
  --dart-define=OMW_USE_GOOGLE_MAPS=true \
  --dart-define=OMW_GOOGLE_MAPS_API_KEY=YOUR_KEY_HERE
```

## Enabling Google Maps (Android / iOS)

Pass the same dart-defines at build time. On Android and iOS the Google Maps
SDK also requires the API key to be embedded in the native manifest:

- Android: `android/app/src/main/AndroidManifest.xml`
  `<meta-data android:name="com.google.android.geo.API_KEY" android:value="…"/>`
- iOS: `ios/Runner/AppDelegate.swift` — `GMSServices.provideAPIKey("…")`

Do NOT commit the API key to Git. Use environment variables or a secrets
manager.

## Dart-define reference

| Flag | Default | Purpose |
|---|---|---|
| `OMW_USE_GOOGLE_MAPS` | `false` | Enable the real Google Maps widget |
| `OMW_GOOGLE_MAPS_API_KEY` | `` | API key passed to the Maps JS / SDK |
| `OPTION_B_USE_GOOGLE_MAPS` | `false` | Legacy alias (still supported) |
| `OPTION_B_GOOGLE_MAPS_API_KEY` | `` | Legacy alias (still supported) |

## When maps are not configured

The app shows a static illustrated map placeholder with the label
**"Map preview / Map not configured"**. All booking, routing, and tracking
flows work normally in this mode — coordinates are still tracked; only the
rendered map tile is replaced by the placeholder.

## Directions / Route estimates

Even without Google Maps tiles, the `DirectionsService` will attempt to call
the Google Routes API if `OMW_GOOGLE_MAPS_API_KEY` is set. If the key is
absent it falls back to straight-line distance estimation automatically.
