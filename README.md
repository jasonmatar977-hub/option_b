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

Open `web/index.html` and find the Google Maps script placeholder:

```html
<script src="https://maps.googleapis.com/maps/api/js?key=YOUR_GOOGLE_MAPS_API_KEY"></script>
```

Replace `YOUR_GOOGLE_MAPS_API_KEY` with your actual key and uncomment the script for local testing. Keep the key restricted in Google Cloud, for example to:

```text
http://localhost/*
```

Then run:

```bash
flutter run -d chrome --dart-define=OPTION_B_USE_GOOGLE_MAPS=true --dart-define=OPTION_B_GOOGLE_MAPS_API_KEY=YOUR_KEY
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

Destination autocomplete uses Google Places when `OPTION_B_GOOGLE_MAPS_API_KEY` is provided. If the key is missing or Places fails, Option B shows local Lebanese fallback suggestions such as Zalka, Zahle, Beirut, Jounieh, Hamra, and Zouk Mikael. Directions uses Google Directions when possible; otherwise the app shows an approximate local distance/time estimate.

Do not commit real API keys.
