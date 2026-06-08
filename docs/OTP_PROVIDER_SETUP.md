# OTP Provider Setup

The Cloud Functions support two WhatsApp OTP providers. The active provider
is selected at runtime via the `OTP_PROVIDER` environment variable.

---

## Providers

| Value | Provider |
|---|---|
| `meta` (default) | Meta WhatsApp Cloud API — manual OTP via text message |
| `twilio` | Twilio Verify — managed OTP via WhatsApp channel |

---

## Twilio Verify (recommended for production)

### Required Firebase secrets

Set these once with the Firebase CLI:

```bash
firebase functions:secrets:set TWILIO_ACCOUNT_SID   --project swiftgo-b74fb
firebase functions:secrets:set TWILIO_AUTH_TOKEN     --project swiftgo-b74fb
firebase functions:secrets:set TWILIO_VERIFY_SERVICE_SID --project swiftgo-b74fb
```

| Secret | Where to find it |
|---|---|
| `TWILIO_ACCOUNT_SID` | Twilio Console → Account → Account SID |
| `TWILIO_AUTH_TOKEN` | Twilio Console → Account → Auth Token |
| `TWILIO_VERIFY_SERVICE_SID` | Twilio Console → Verify → Services → your service → Service SID |

> Do NOT commit these values to git. They are stored encrypted in Firebase Secret Manager.

### Activate Twilio provider

Set the `OTP_PROVIDER` environment variable in `functions/.env`:

```
OTP_PROVIDER=twilio
```

Or pass it at deploy time via `--set-env-vars`:

```bash
firebase deploy --only functions \
  --set-env-vars OTP_PROVIDER=twilio \
  --project swiftgo-b74fb
```

### Deploy command

```bash
firebase deploy --only functions --project swiftgo-b74fb
```

### Twilio Verify service configuration

In the Twilio Console → Verify → Services → your service:
- **WhatsApp channel**: enabled
- **Code length**: 6 digits
- **Expiry**: 10 minutes (Twilio default; OMW enforces 5 minutes client-side)
- **Max attempts**: 5 (Twilio default)

---

## Meta WhatsApp Cloud API (legacy / fallback)

### Required secret

```bash
firebase functions:secrets:set META_WHATSAPP_ACCESS_TOKEN --project swiftgo-b74fb
```

### Environment variables (`functions/.env`)

```
META_WHATSAPP_PHONE_NUMBER_ID=<your_phone_number_id>
META_WHATSAPP_BUSINESS_ACCOUNT_ID=<your_business_account_id>
WHATSAPP_OTP_TEST_MODE=true
WHATSAPP_OTP_ALLOWED_TESTERS=961XXXXXXXXX,961YYYYYYYYY
OTP_PROVIDER=meta
```

When `OTP_PROVIDER` is absent or set to `meta`, the Meta path is used.

---

## Switching providers

To switch from Twilio back to Meta:

1. In `functions/.env`, change:
   ```
   OTP_PROVIDER=meta
   ```
2. Redeploy:
   ```bash
   firebase deploy --only functions --project swiftgo-b74fb
   ```

No code changes are required. The provider switch is purely runtime configuration.

---

## How to test Twilio

1. Set secrets as above.
2. Set `OTP_PROVIDER=twilio` in `functions/.env`.
3. Deploy functions.
4. Open the OMW app → Account tab → Log in with WhatsApp.
5. Enter a phone number registered with the Twilio Verify service (WhatsApp channel must be active on that number).
6. Twilio sends a 6-digit code via WhatsApp.
7. Enter the code in the app.
8. On success, the user is authenticated and the Account tab shows their profile.

**Test numbers**: Twilio Verify supports test credentials
(`TWILIO_ACCOUNT_SID=ACtest...`) for automated testing without sending real messages.
See [Twilio docs](https://www.twilio.com/docs/verify/api).

---

## Error messages (customer-facing)

| Scenario | Message |
|---|---|
| Code send failed | "Could not send WhatsApp code. Please try again." |
| Wrong / expired code | "Invalid or expired code." |
| Too many attempts | "Too many attempts. Please wait and try again." |
| Credentials not configured | "Twilio credentials are not configured." (dev only) |
