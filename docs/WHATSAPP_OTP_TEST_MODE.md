# OMW WhatsApp OTP Test Mode

This app uses Firebase Callable Functions for WhatsApp OTP. The Meta access
token must never be added to Flutter, web files, or Git.

## Function Names

- `sendWhatsAppOtp`
- `verifyWhatsAppOtp`
- `requestWhatsAppOtp` is kept as a compatibility alias.

## Required Backend Config

Set the Meta token as a Firebase Functions secret:

```bash
firebase functions:secrets:set META_WHATSAPP_ACCESS_TOKEN
```

Set environment variables for the Functions runtime:

```bash
META_WHATSAPP_PHONE_NUMBER_ID=1137966846065788
META_WHATSAPP_BUSINESS_ACCOUNT_ID=934349259649903
WHATSAPP_OTP_TEST_MODE=true
WHATSAPP_OTP_ALLOWED_TESTERS=15556633338,961XXXXXXXX
```

`WHATSAPP_OTP_ALLOWED_TESTERS` is a comma-separated list. Numbers can include
`+`, spaces, or dashes; the function normalizes them to country-code digits.

If `WHATSAPP_OTP_ALLOWED_TESTERS` is empty in test mode, the function returns:

`WhatsApp OTP test numbers are not configured yet. Please contact OMW admin.`

## Tomorrow: 5-Tester Setup Checklist

Work through these steps in order. Do not skip step 9 — keep the SMS/demo
fallback working until WhatsApp OTP is confirmed on all 5 numbers.

### Step 1 — Meta Business Suite: add test recipients

1. Open [Meta Business Suite](https://business.facebook.com) → WhatsApp →
   Getting started → Test numbers.
2. Add all 5 WhatsApp numbers as approved test recipients.
3. Each number must **accept** the test-recipient invitation in WhatsApp before
   it can receive messages.

### Step 2 — Normalize tester phone numbers

Numbers in `WHATSAPP_OTP_ALLOWED_TESTERS` must be in international format
**without** leading `+`, spaces, or dashes.

Example: `+961 70 123 456` → `96170123456`

Prepare the five normalized numbers as a comma-separated string:
```
96170XXXXXX,96171XXXXXX,96176XXXXXX,96170YYYYYY,96178YYYYYY
```

### Step 3 — Set Firebase Functions environment config

```bash
# Secret — never committed to Git
firebase functions:secrets:set META_WHATSAPP_ACCESS_TOKEN
# (paste the token when prompted)

# Non-secret runtime config
firebase functions:config:set \
  omw.meta_whatsapp_phone_number_id="1137966846065788" \
  omw.meta_whatsapp_business_account_id="934349259649903" \
  omw.whatsapp_otp_test_mode="true" \
  omw.whatsapp_otp_allowed_testers="96170XXXXXX,96171XXXXXX,..."
```

Confirm these values are set:

| Key | Value |
|---|---|
| `META_WHATSAPP_PHONE_NUMBER_ID` | `1137966846065788` |
| `META_WHATSAPP_BUSINESS_ACCOUNT_ID` | `934349259649903` |
| `WHATSAPP_OTP_TEST_MODE` | `true` |
| `WHATSAPP_OTP_ALLOWED_TESTERS` | 5 normalized numbers |

### Step 4 — Deploy Firebase Functions

```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

Watch the deploy output for any errors. If it fails, fix before proceeding.

### Step 5 — Build and run Flutter with Firebase

```bash
flutter run -d chrome \
  --dart-define=OMW_USE_FIREBASE=true \
  --dart-define=OMW_USE_WHATSAPP_OTP=true
```

Or for the web release:

```bash
flutter build web --release \
  --base-href=/option_b/ \
  --dart-define=OMW_USE_FIREBASE=true \
  --dart-define=OMW_USE_WHATSAPP_OTP=true
```

### Step 6 — Test with Jason's number first

1. Open the app → Continue as Customer (or any role).
2. Enter Jason's WhatsApp number (with country code `+961…`).
3. Tap **Send code on WhatsApp**.
4. Confirm the OTP message arrives in WhatsApp.
5. Enter the 6-digit code and verify login succeeds.

### Step 7 — Test with remaining 4 tester numbers

Repeat Step 6 for each of the other 4 approved test numbers.
If a number fails, confirm it accepted the Meta test-recipient invitation
(Step 1) and that it appears in `WHATSAPP_OTP_ALLOWED_TESTERS` (Step 3).

### Step 8 — Confirm SMS fallback still works

On the login screen, tap **Use emergency SMS fallback** and verify that SMS
OTP still works for at least one number. Do not remove this fallback before
WhatsApp OTP has been confirmed stable for all 5 testers.

### Step 9 — Keep fallback available

Leave `OMW_DISABLE_WHATSAPP_OTP` unset (or `false`) so the WhatsApp toggle
remains visible but the SMS emergency fallback button also stays visible.
Only disable the SMS fallback after a full production rollout is confirmed.

## Local Build Checks

```bash
cd functions
npm install
npm run build
```

Flutter:

```bash
dart format lib
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter build web --release --base-href=/option_b/
```

## OTP Storage

OTP records are stored in Firestore collection `whatsappOtpSessions`.

Fields:

- `phoneNumber`
- `normalizedPhoneNumber`
- `otpHash`
- `expiresAt`
- `attempts`
- `maxAttempts`
- `verified`
- `createdAt`
- `updatedAt`
- `verifiedAt`

The plain OTP is not stored. The function stores a SHA-256 hash scoped to the
normalized phone number.

## Meta Message

Test mode sends a text message through:

`POST https://graph.facebook.com/v20.0/1137966846065788/messages`

Body text:

`Your OMW verification code is: 123456`

If Meta blocks free-form text outside the test/conversation window, switch to an
approved authentication template before production release.

## Production Hardening Later

- Use an approved WhatsApp authentication template.
- Move non-secret config to managed Functions environment config for the target
  Firebase project.
- Add App Check enforcement.
- Add IP/rate limits beyond the current per-number cooldown and attempt limit.
- Add audit logging and abuse monitoring.
