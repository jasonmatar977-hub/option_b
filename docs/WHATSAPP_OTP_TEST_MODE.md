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

## Tomorrow Tester Setup

1. Add the 5 recipient WhatsApp numbers in Meta test mode.
2. Add the same 5 numbers to `WHATSAPP_OTP_ALLOWED_TESTERS`.
3. Deploy Functions.
4. Build/run Flutter with Firebase enabled.
5. Use the login screen WhatsApp OTP option.

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
