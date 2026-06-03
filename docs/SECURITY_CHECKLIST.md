# OMW — Production Security Checklist

Project: **swiftgo-b74fb** | Firebase project: `swiftgo-b74fb`
Deployed URL: `https://jasonmatar977-hub.github.io/option_b/`

Complete every item below before enabling real customer traffic.

---

## 1. Firebase Authorized Domains

Firebase Console → Authentication → Settings → **Authorized domains**

Ensure these domains are listed:

| Domain | Purpose |
|--------|---------|
| `localhost` | Local development |
| `jasonmatar977-hub.github.io` | GitHub Pages deployment |

Any custom domain you add for the app must also be listed here before
email-link auth, password-reset links, and email verification redirects will work.

---

## 2. Google Maps / Places API Key Restrictions

The Maps API key is passed at build time via:
```
--dart-define=OMW_GOOGLE_MAPS_API_KEY=YOUR_KEY
```

In **Google Cloud Console → APIs & Services → Credentials**:

1. Select the browser key used for this app.
2. Under **Application restrictions** choose **HTTP referrers (web sites)**.
3. Add the following referrers:

```
https://jasonmatar977-hub.github.io/*
http://localhost/*
http://localhost:*/*
```

4. Under **API restrictions** → Restrict key to:
   - Maps JavaScript API
   - Places API
   - Directions API (if used)
   - Geocoding API (if used)

5. Never expose this key in source control. It is injected at build time only.

---

## 3. Firebase App Check (REQUIRED before public launch)

App Check prevents unauthorized clients from hitting your Firestore, Storage,
and Cloud Functions quota.

**Status: NOT yet configured** — see `TODO` comment in
`lib/services/firebase_service.dart`.

### Steps

#### 3a. Enable reCAPTCHA Enterprise (recommended for web)

1. Google Cloud Console → Enable **reCAPTCHA Enterprise API** for `swiftgo-b74fb`.
2. reCAPTCHA Enterprise → **Create Key** → choose **Website** → add domains:
   - `jasonmatar977-hub.github.io`
   - `localhost`
3. Copy the **site key** (not the secret key).

#### 3b. Register in Firebase Console

1. Firebase Console → App Check → **Get started**.
2. Select your **Web app**.
3. Choose **reCAPTCHA Enterprise** → paste the site key → Register.

#### 3c. Add to Flutter app

```yaml
# pubspec.yaml
dependencies:
  firebase_app_check: ^0.3.2  # check pub.dev for latest
```

Add `--dart-define=OMW_RECAPTCHA_SITE_KEY=YOUR_SITE_KEY` to all build commands.

Add to `lib/config/app_config.dart`:
```dart
static const String recaptchaSiteKey = String.fromEnvironment(
  'OMW_RECAPTCHA_SITE_KEY',
  defaultValue: '',
);
```

In `lib/services/firebase_service.dart`, inside `initialize()` after
`Firebase.initializeApp(...)`:
```dart
import 'package:firebase_app_check/firebase_app_check.dart';

if (AppConfig.recaptchaSiteKey.isNotEmpty) {
  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaEnterpriseProvider(AppConfig.recaptchaSiteKey),
  );
}
```

#### 3d. Enforce in Firebase Console

After testing that App Check tokens flow correctly:

1. Firebase Console → App Check → Firestore → **Enforce**.
2. Firebase Console → App Check → Storage → **Enforce**.
3. Firebase Console → App Check → Functions → **Enforce** (after Cloud Functions go live).

**Do NOT enforce before confirming the Flutter app sends valid tokens —
enforcing on a broken config locks out all clients.**

---

## 4. Firestore Rules Deploy

Rules file: `firestore.rules`

```bash
firebase deploy --only firestore:rules --project swiftgo-b74fb
```

Verify the deployed rules version in Firebase Console → Firestore → Rules.

Key invariants enforced (see `firestore.rules` for full detail):
- `users/{uid}.roles` — users cannot self-assign `owner`/`admin`
- `stores/{id}` — store owners cannot approve themselves
- `workers/{id}` — workers cannot self-approve
- `marketplaceOrders` — worker dispatch uses `deliveryStatus` field
- `workerDocuments` — only owning worker or admin can read

---

## 5. Storage Rules Deploy

Rules file: `storage.rules`

```bash
firebase deploy --only storage --project swiftgo-b74fb
```

Key invariants:
- Store images: public read, write requires `ownsStore()` Firestore check
- Worker documents: read only by owning worker or admin/owner
- Worker document upload: size ≤ 20 MB, image or PDF only

---

## 6. Firestore Indexes Deploy

Index definitions: `firestore.indexes.json` (10 composite indexes)

```bash
firebase deploy --only firestore:indexes --project swiftgo-b74fb
```

Or deploy all Firestore resources at once:

```bash
firebase deploy --only firestore --project swiftgo-b74fb
```

Monitor index build status: Firebase Console → Firestore → **Indexes**.
Queries will throw `failed-precondition` until the relevant index reaches
**Enabled** status (typically 2–10 minutes per index).

---

## 7. Admin Email Bootstrap Warning

The admin email is compiled into the app binary via:
```
--dart-define=OMW_ADMIN_EMAILS=jasonmatar977@gmail.com
```

**Risk**: Anyone who knows the admin email address and signs up with it
*for the first time* will have their `users/{uid}` document created with
`roles: ['owner']`.

**Mitigations currently in place**:
- Email verification is required before any privileged screens are accessible
- The `owner` role is assigned only at document *creation* time; subsequent
  logins for non-owner accounts cannot escalate via the rules
- Firestore rules block `owner`/`admin` role updates by non-admin users

**Long-term fix**: Migrate to Firebase Auth Custom Claims assigned by a
trusted Cloud Function after identity verification. This removes the
client-side bootstrap entirely.

**Before launch**: Ensure the admin email account uses a strong password,
and enable multi-factor authentication (MFA) in Firebase Console →
Authentication → Users.

---

## 8. Environment Variables Reference

All secrets and environment-specific values are injected at build time.
**Never commit real values to source control.**

| Variable | Used for | Required |
|----------|---------|----------|
| `OMW_USE_FIREBASE=true` | Enable Firebase | Yes |
| `OMW_USE_GOOGLE_MAPS=true` | Enable real Maps | Yes |
| `OMW_GOOGLE_MAPS_API_KEY=...` | Browser Maps key | Yes |
| `OMW_SUPPORT_WHATSAPP_NUMBER=961...` | Support chat link | Yes |
| `OMW_ADMIN_EMAILS=email@...` | Bootstrap admin | Yes |
| `OMW_RECAPTCHA_SITE_KEY=...` | App Check (web) | Required for App Check |

Full build command template:
```bash
flutter build web --release \
  --base-href=/option_b/ \
  --dart-define=OMW_USE_FIREBASE=true \
  --dart-define=OMW_USE_GOOGLE_MAPS=true \
  --dart-define=OMW_GOOGLE_MAPS_API_KEY=YOUR_MAPS_KEY \
  --dart-define=OMW_SUPPORT_WHATSAPP_NUMBER=961XXXXXXXX \
  --dart-define=OMW_ADMIN_EMAILS=your_admin@example.com
```

---

## 9. Pre-launch Audit Checklist

- [ ] Firebase Authorized Domains includes the deployed domain
- [ ] Google Maps API key restricted to allowed referrers
- [ ] `firestore.rules` deployed and up to date
- [ ] `storage.rules` deployed and up to date
- [ ] `firestore.indexes.json` deployed, all indexes **Enabled**
- [ ] App Check registered and tested (not yet enforced)
- [ ] App Check **Enforce** enabled after successful validation
- [ ] Admin email uses strong password + MFA
- [ ] No real API keys or secrets in source control
- [ ] All `debugPrint` calls containing PII are `kDebugMode`-guarded
- [ ] Firebase Console → Usage tab reviewed for unexpected reads/writes
- [ ] Firebase Console → Auth → Sign-in providers: only Email/Password enabled
  (disable Phone and anonymous unless actively used)
