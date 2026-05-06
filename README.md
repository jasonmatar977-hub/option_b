# Option B

Option B is a simple map-first Flutter demo for offer-based ride, moto, and courier requests.

The app is intentionally client-only:

- No backend
- No Firebase
- No payments
- Fake map fallback stays available

## Google Maps Setup

Enable these Google APIs for the key used by this demo:

- Maps JavaScript API
- Places API
- Directions API
- Geocoding API

### Web / Chrome

For local Chrome testing, pass the API key at runtime. Do not commit a real key:

```bash
flutter run -d chrome --dart-define=OPTION_B_USE_GOOGLE_MAPS=true --dart-define=OPTION_B_GOOGLE_MAPS_API_KEY=YOUR_KEY
```

`Option B` uses that dart define to load Google Maps JavaScript when needed. Keep `web/index.html` free of a live Maps script so the app has one source of truth for loading Maps. Do not paste a real key into source control.

Google Cloud website referrers must include:

```text
http://localhost/*
https://jasonmatar977-hub.github.io/*
https://jasonmatar977-hub.github.io/option_b/*
```

If you run without that dart define, Option B uses the fake map fallback:

```bash
flutter run -d chrome
```

### Android

Open `android/app/src/main/AndroidManifest.xml` and replace the placeholder:

```xml
android:value="YOUR_GOOGLE_MAPS_API_KEY"
```

Then run:

```bash
flutter run -d android --dart-define=OPTION_B_USE_GOOGLE_MAPS=true
```

Android location permissions are already declared:

- `android.permission.ACCESS_FINE_LOCATION`
- `android.permission.ACCESS_COARSE_LOCATION`

## Fallback Behavior

Google Maps is opt-in through:

```bash
--dart-define=OPTION_B_USE_GOOGLE_MAPS=true
--dart-define=OPTION_B_GOOGLE_MAPS_API_KEY=YOUR_KEY
```

Without that flag, the app always uses the fake map. If location permission is denied or GPS is unavailable, the app keeps the default demo pickup location and the customer flow still works.

Destination autocomplete avoids direct Google REST calls from Flutter web because those endpoints are blocked by browser CORS. Option B shows local Lebanese suggestions such as Zalka, Zahle, Beirut, Jounieh, Hamra, and Zouk Mikael. ETA/distance also avoids direct Directions REST calls and uses a local Haversine estimate with service-specific average speeds. Estimates are labeled approximate.

Do not commit real API keys.
