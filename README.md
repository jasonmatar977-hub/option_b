# On My Way

On My Way is a map-first Flutter app for offer-based ride, moto, and courier requests.

The app currently keeps the branded local fallback UI active while the production Firebase foundation is added. Payments and Firebase Messaging are intentionally out of scope for this phase.

## Production Phase 1

Phase 1 prepares the backend architecture without forcing a risky screen cutover:

- Central app config in `lib/config/app_config.dart`
- Firestore-ready production models in `lib/models/backend_models.dart`
- Firebase services for auth, users, workers, jobs, driver locations, chat, and storage
- Local fallback remains enabled by default
- Existing customer, driver, owner, and Google Maps flows stay runnable

## Firebase Setup

Create and configure a Firebase project:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

`flutterfire configure` should replace `lib/firebase_options.dart` with real project options. Until then, Firebase initialization is caught and the app logs:

```text
Firebase not configured. Running in local fallback mode.
```

In Firebase Console:

- Enable Authentication
- Enable the Phone provider
- Enable Cloud Firestore
- Enable Cloud Storage
- Add the Android app with the package name from `android/app/build.gradle.kts`
- Add the Web app if testing Firebase Auth on Chrome

Required Firestore collections:

- `users`
- `workers`
- `workerDocuments`
- `jobs`
- `driverLocations`
- `marketplaceStores`
- `marketplaceProducts`
- `marketplaceOrders`
- `jobChats`
- `jobChats/{jobId}/messages`

Document ID plan:

- `users/{uid}`
- `workers/{workerId}`
- `workerDocuments/{documentId}`
- `jobs/{jobId}`
- `driverLocations/{workerId}`
- `marketplaceStores/{storeId}`
- `marketplaceProducts/{productId}`
- `marketplaceOrders/{orderId}`
- `jobChats/{jobId}/messages/{messageId}`

`jobs` required fields:

- `customerId`, `customerPhone`, `customerName`
- `serviceType`: `ride`, `moto`, or `courier`
- `pickupLabel`, `pickupLat`, `pickupLng`
- `destinationLabel`, `destinationLat`, `destinationLng`
- `offerAmount`
- `paymentMethod`: `cash` or `card`
- `status`: `pending`, `accepted`, `active`, `completed`, `rejected`, or `cancelled`
- `assignedWorkerId`, `assignedWorkerName`, `assignedWorkerPhone`
- `createdAt`, `acceptedAt`, `startedAt`, `completedAt`, `cancelledAt`, `rejectedAt`
- `gross`, `platformCommission`, `workerPayout`

Production Phase 3 connects Firebase mode to real Firestore jobs:

- Customers create `jobs` documents when sending OMW offers.
- Drivers watch pending nearby jobs and accept/reject with Firestore updates.
- Owners watch live jobs and dashboard metrics from Firestore.
- Local fallback remains active when Firebase is disabled or unavailable.

Production Phase 4 adds app-open live driver location tracking:

- Approved workers can go online and write `driverLocations/{workerId}`.
- Online worker location updates are sent while the app is open.
- Customer tracking listens to the assigned worker location.
- Owner dashboard reads online workers from `driverLocations`.
- No background location tracking is enabled yet.

Marketplace Phase 1 adds the customer marketplace foundation:

- Customers can open `OMW Marketplace` from the customer service selector.
- The app includes local fallback stores, products, cart, checkout, and basic tracking.
- Marketplace models and service methods are Firestore-ready.
- Owner/Admin has a marketplace metrics panel.
- Courier delivery integration is prepared with a driver placeholder; full marketplace dispatch is planned for the next marketplace phase.

Firebase persistence now supports cross-browser/device testing:

- `users/{uid}` stores the Firebase user, phone number, selected role, timestamps, and active flag.
- Returning Firebase users restore their saved role after refresh/reopen when possible.
- `workers/{uid}` stores worker applications, approval status, and online/offline state.
- `workers/{uid}/documents/{documentType}` stores worker document metadata and review status.
- Owner/Admin reads Firestore worker applications and can approve, reject, or suspend them.
- Owner/Admin reviews individual worker documents before final worker approval.
- Marketplace checkout writes real `marketplaceOrders/{orderId}` documents in Firebase mode.
- Approved online couriers read pending marketplace orders from Firestore and accept them with a transaction so already accepted orders are blocked cleanly.
- Customer marketplace tracking listens to the saved order document and updates when a courier accepts or completes delivery.

Security rules TODO:

- Customers can create and read their own jobs.
- Approved workers can read pending jobs.
- Assigned workers can update assigned jobs.
- Owner/admin users can read and manage all jobs.
- Workers can upload/read their own documents under `workers/{uid}/documents`.
- Owner/admin users can read/review worker documents.

Worker document verification:

- Required: `profilePhoto`, `governmentId`, `driverLicense`, `vehicleRegistration`, `vehiclePhoto`
- Optional: `insurance`, `backgroundCheck`
- Files are stored in Firebase Storage at `workers/{workerId}/documents/{documentType}/{timestamp}_{filename}`
- Firestore stores metadata only: `type`, `status`, `fileUrl`, `fileName`, `storagePath`, `uploadedAt`, `reviewedAt`, and optional `rejectionReason`
- Supported uploads: JPG, JPEG, PNG, PDF
- Max upload size: 10MB
- Local fallback keeps local-only fake uploads for fast testing when Firebase is disabled.
- Firebase mode requires Storage to be enabled before worker document upload works.

Revenue and payout model:

- Default commission rate is 15% (`AppConfig.defaultCommissionRate` / `AppConfig.commissionRate`).
- Gross revenue is the customer offer amount or marketplace order total.
- Owner net earnings are the platform commission.
- Worker payout is 85% of gross by default.
- No real payment gateway is integrated yet.
- Current payment status is treated as manual until a real payment provider is added.
- Owner/Admin manually marks worker payouts as `paid` or `disputed`.
- Drivers cannot mark themselves paid.

Worker agreement and payout setup:

- Workers must accept the On My Way Worker Agreement before submitting/operating.
- Stored fields: `agreementAccepted`, `agreementAcceptedAt`, `agreementVersion`.
- Payout methods: Wish Money, OMT Pay, Cash, Bank Transfer, Other.
- Stored payout fields: `payoutMethod`, `payoutDisplayName`, `payoutPhoneNumber`, `payoutNotes`.
- Final worker agreement and payout terms should be reviewed by a qualified lawyer before public launch.

`driverLocations` fields:

- `workerName`, `workerPhone`
- `lat`, `lng`
- `heading`, `speed`
- `isOnline`
- `activeJobId`
- `updatedAt`

Marketplace collections:

- `marketplaceStores`: `name`, `category`, `imageUrl`, `rating`, `isOpen`, `lat`, `lng`, `address`, `deliveryEstimateMinutes`
- `marketplaceProducts`: `storeId`, `name`, `description`, `price`, `imageUrl`, `category`, `isAvailable`
- `marketplaceOrders`: `id`, `customerId`, `customerPhone`, `storeId`, `storeName`, `storeAddress`, `storeLat`, `storeLng`, `items`, `itemCount`, `subtotal`, `deliveryFee`, `total`, `paymentMethod`, `deliveryLabel`, `deliveryLat`, `deliveryLng`, `status`, `assignedWorkerId`, `assignedWorkerName`, `assignedWorkerPhone`, timestamps

Marketplace payments are placeholders only. Cash is usable in the app; card shows a coming-soon message until a real payment provider is added.

Run in local fallback mode:

```bash
flutter run
```

Run with Firebase mode:

```bash
flutter run --dart-define=OMW_USE_FIREBASE=true
```

Run with Firebase and Google Maps on Chrome:

```bash
flutter run -d chrome --dart-define=OMW_USE_FIREBASE=true --dart-define=OMW_USE_GOOGLE_MAPS=true --dart-define=OMW_GOOGLE_MAPS_API_KEY=YOUR_KEY
```

Run local fallback with Google Maps on Chrome:

```bash
flutter run -d chrome --dart-define=OMW_USE_FIREBASE=false --dart-define=OMW_USE_GOOGLE_MAPS=true --dart-define=OMW_GOOGLE_MAPS_API_KEY=YOUR_KEY
```

Location permissions:

- Android already declares `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION`.
- Web/Chrome will ask for browser location permission when the driver goes online.
- Background location permission is intentionally not requested in this phase.

Legacy compatibility is still supported temporarily:

```bash
flutter run --dart-define=OPTION_B_USE_FIREBASE=true
```

Firebase Phone Auth, Firestore jobs, live driver location, worker approval persistence, and marketplace order persistence are wired into the screens when Firebase mode is enabled. The existing demo OTP, local worker onboarding, local marketplace orders, owner dashboard, and driver offer flow remain active when Firebase is disabled.

## Phone Authentication

Production Phase 2 wires the login screens to Firebase Phone Auth when Firebase is enabled and initialized.

Production Phase 5 adds a WhatsApp OTP foundation. WhatsApp OTP is never sent directly from Flutter; the app calls Firebase Cloud Functions:

- `requestWhatsAppOtp(phoneNumber, role)`
- `verifyWhatsAppOtp(phoneNumber, code, role)`

The backend function sends and verifies the WhatsApp code through Twilio Verify, creates a Firebase custom token, and the app signs in with that token. Twilio credentials are never stored in Flutter or committed to source.

Firebase mode:

```bash
flutter run --dart-define=OMW_USE_FIREBASE=true
```

Phone numbers must include the country code, for example:

```text
+96170123456
```

If Firebase is disabled or unavailable, the app keeps the local fallback OTP:

```text
1234
```

After a successful Firebase login, the app creates or updates `users/{uid}` with the selected role, phone number, display name, `createdAt`, `lastLoginAt`, and `isActive`. Owner/Admin login currently uses phone auth too; production owner permissions should later be enforced with Firestore roles or custom claims.

WhatsApp OTP mode:

```bash
flutter run --dart-define=OMW_USE_FIREBASE=true --dart-define=OMW_USE_WHATSAPP_OTP=true
```

If WhatsApp callable functions are unavailable, the app can fall back to Firebase SMS when Firebase Auth is enabled. If the Twilio provider credentials are missing, the app shows a clear setup error and does not fake a WhatsApp success. Demo OTP `1234` is only used when Firebase/backend auth is disabled.

### WhatsApp OTP Functions

Cloud Functions live in `functions/`.

Install/build:

```bash
cd functions
npm install
npm run build
```

Production provider:

- Twilio Verify WhatsApp

Future provider option documented in code:

- Meta WhatsApp Business Platform authentication templates

Twilio setup:

1. Create a Twilio account.
2. Enable Twilio Verify with WhatsApp support.
3. Create a Verify Service and copy the Verify Service SID.
4. Copy the Account SID and Auth Token from Twilio Console.
5. Set Firebase Functions secrets:

```bash
firebase functions:secrets:set TWILIO_ACCOUNT_SID
firebase functions:secrets:set TWILIO_AUTH_TOKEN
firebase functions:secrets:set TWILIO_VERIFY_SERVICE_SID
```

Twilio is the default provider. For local emulator or advanced deployments, set `OMW_WHATSAPP_PROVIDER=twilio` in the Functions environment if you need to override the provider.

Then deploy:

```bash
firebase deploy --only functions
```

The Functions code uses Twilio Verify with `channel: "whatsapp"`. `requestWhatsAppOtp` starts a Twilio verification and `verifyWhatsAppOtp` checks the code through Twilio before creating a Firebase custom token. OTP sessions are tracked in `otpSessions` with provider metadata, expiry, attempts, timestamps, and status. Raw OTP values are not stored by On My Way.

## Google Maps Setup

Enable these Google APIs for the key used by this demo:

- Maps JavaScript API
- Places API
- Directions API
- Geocoding API

### Web / Chrome

For local Chrome testing, pass the API key at runtime. Do not commit a real key:

```bash
flutter run -d chrome --dart-define=OMW_USE_GOOGLE_MAPS=true --dart-define=OMW_GOOGLE_MAPS_API_KEY=YOUR_KEY
```

`On My Way` uses that dart define to load Google Maps JavaScript when needed. Keep `web/index.html` free of a live Maps script so the app has one source of truth for loading Maps. Do not paste a real key into source control.

Legacy map defines remain supported temporarily:

```bash
flutter run -d chrome --dart-define=OPTION_B_USE_GOOGLE_MAPS=true --dart-define=OPTION_B_GOOGLE_MAPS_API_KEY=YOUR_KEY
```

Google Cloud website referrers must include:

```text
http://localhost/*
https://jasonmatar977-hub.github.io/*
https://jasonmatar977-hub.github.io/option_b/*
```

If you run without that dart define, On My Way uses the fake map fallback:

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
flutter run -d android --dart-define=OMW_USE_GOOGLE_MAPS=true
```

Android location permissions are already declared:

- `android.permission.ACCESS_FINE_LOCATION`
- `android.permission.ACCESS_COARSE_LOCATION`

## Fallback Behavior

Google Maps is opt-in through:

```bash
--dart-define=OMW_USE_GOOGLE_MAPS=true
--dart-define=OMW_GOOGLE_MAPS_API_KEY=YOUR_KEY
```

Without that flag, the app always uses the fake map. If location permission is denied or GPS is unavailable, the app keeps the default demo pickup location and the customer flow still works.

Destination autocomplete avoids direct Google REST calls from Flutter web because those endpoints are blocked by browser CORS. On My Way shows local Lebanese suggestions such as Zalka, Zahle, Beirut, Jounieh, Hamra, and Zouk Mikael. ETA/distance also avoids direct Directions REST calls and uses a local Haversine estimate with service-specific average speeds. Estimates are labeled approximate.

## Security

Never commit real API keys, Firebase service account files, signing credentials, or other secrets. Runtime keys must be passed through dart defines or platform-specific secure configuration.

## Validation

Run before handing off production changes:

```bash
flutter pub get
flutter analyze
flutter test
```
