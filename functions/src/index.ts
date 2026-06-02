import * as crypto from "crypto";
import * as admin from "firebase-admin";
import { defineSecret } from "firebase-functions/params";
import { HttpsError, onCall } from "firebase-functions/v2/https";

admin.initializeApp();

const db = admin.firestore();
const otpCollection = "whatsappOtpSessions";
const usersCollection = "users";
const maxAttempts = 5;
const expiryMs = 5 * 60 * 1000;
const minRequestSpacingMs = 60 * 1000;
const defaultPhoneNumberId = "1137966846065788";
const defaultBusinessAccountId = "934349259649903";

const metaAccessToken = defineSecret("META_WHATSAPP_ACCESS_TOKEN");

type OtpRole = "customer" | "worker" | "storeOwner" | "owner";

function normalizePhone(raw: unknown): { e164: string; digits: string } {
  if (typeof raw !== "string") {
    throw new HttpsError("invalid-argument", "Phone number is required.");
  }
  const trimmed = raw.trim();
  const digits = trimmed.replace(/[^\d]/g, "");
  if (!/^[1-9]\d{7,14}$/.test(digits)) {
    throw new HttpsError(
      "invalid-argument",
      "Phone number must include country code, for example +961...",
    );
  }
  return { e164: `+${digits}`, digits };
}

function normalizeRole(raw: unknown): OtpRole {
  if (
    raw === "customer" ||
    raw === "worker" ||
    raw === "storeOwner" ||
    raw === "owner"
  ) {
    return raw;
  }
  return "customer";
}

function normalizeCode(raw: unknown): string {
  const code = String(raw ?? "").trim();
  if (!/^\d{6}$/.test(code)) {
    throw new HttpsError(
      "invalid-argument",
      "Verification code must be 6 digits.",
    );
  }
  return code;
}

function isTestMode(): boolean {
  return (process.env.WHATSAPP_OTP_TEST_MODE ?? "true").toLowerCase() !==
    "false";
}

function allowedTesterDigits(): string[] {
  return (process.env.WHATSAPP_OTP_ALLOWED_TESTERS ?? "")
    .split(",")
    .map((entry) => entry.replace(/[^\d]/g, ""))
    .filter((entry) => entry.length > 0);
}

function assertTesterAllowed(phoneDigits: string): void {
  if (!isTestMode()) return;
  const testers = allowedTesterDigits();
  if (testers.length === 0) {
    throw new HttpsError(
      "failed-precondition",
      "WhatsApp OTP test numbers are not configured yet. Please contact OMW admin.",
    );
  }
  if (!testers.includes(phoneDigits)) {
    throw new HttpsError(
      "permission-denied",
      "This WhatsApp number is not enabled for testing yet.",
    );
  }
}

function sessionIdFor(phoneDigits: string): string {
  return crypto.createHash("sha256").update(phoneDigits).digest("hex");
}

function otpHash(phoneDigits: string, code: string): string {
  return crypto
    .createHash("sha256")
    .update(`${phoneDigits}:${code}:omw-whatsapp-otp-v1`)
    .digest("hex");
}

function generateOtp(): string {
  const value = crypto.randomInt(0, 1000000);
  return value.toString().padStart(6, "0");
}

async function sendMetaWhatsAppText(
  phoneDigits: string,
  code: string,
): Promise<string> {
  const token = metaAccessToken.value();
  console.log("[sendMeta] token present:", !!token, "| phoneDigits suffix:", phoneDigits.slice(-4));
  if (!token) {
    throw new HttpsError(
      "failed-precondition",
      "WhatsApp provider token is not configured.",
    );
  }
  const phoneNumberId =
    process.env.META_WHATSAPP_PHONE_NUMBER_ID ?? defaultPhoneNumberId;
  console.log("[sendMeta] phoneNumberId:", phoneNumberId);

  let response: Response;
  try {
    response = await fetch(
      `https://graph.facebook.com/v20.0/${phoneNumberId}/messages`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          messaging_product: "whatsapp",
          to: phoneDigits,
          type: "text",
          text: {
            preview_url: false,
            body: `Your OMW verification code is: ${code}`,
          },
        }),
      },
    );
  } catch (networkErr) {
    console.error("[sendMeta] network error:", String(networkErr));
    throw new HttpsError(
      "unavailable",
      "WhatsApp provider request failed. Check backend logs.",
    );
  }

  const body = (await response.json().catch(() => ({}))) as {
    messages?: Array<{ id?: string; message_status?: string }>;
    error?: { message?: string; code?: number; type?: string };
  };
  console.log("[sendMeta] HTTP status:", response.status);
  if (!response.ok) {
    console.error(
      "[sendMeta] Meta API rejected request | status:", response.status,
      "| error code:", body.error?.code,
      "| error type:", body.error?.type,
      "| error message:", body.error?.message,
    );
    throw new HttpsError(
      "unavailable",
      "WhatsApp provider rejected the OTP request. Check Meta token, phone number ID, and test recipient.",
    );
  }
  const messageStatus = body.messages?.[0]?.message_status ?? "accepted";
  console.log("[sendWhatsAppOtp] WhatsApp OTP send accepted by Meta | message_status:", messageStatus);
  return messageStatus;
}

async function issueCustomToken(phoneNumber: string, role: OtpRole) {
  const uid = `phone:${phoneNumber}`;
  await admin
    .auth()
    .updateUser(uid, { phoneNumber })
    .catch(async (error: { code?: string }) => {
      if (error.code === "auth/user-not-found") {
        await admin.auth().createUser({ uid, phoneNumber });
        return;
      }
      throw error;
    });
  await admin.auth().setCustomUserClaims(uid, {
    role,
    phoneNumber,
    authProvider: "whatsapp_otp_test",
  });
  return admin.auth().createCustomToken(uid, {
    phoneNumber,
    role,
    provider: "whatsapp_otp_test",
  });
}

async function upsertUserProfile(uid: string, phoneNumber: string, role: OtpRole) {
  const now = admin.firestore.FieldValue.serverTimestamp();
  const userRef = db.collection(usersCollection).doc(uid);
  const existing = await userRef.get();
  const roles = new Set<string>([
    ...((existing.get("roles") as string[] | undefined) ?? []),
    role,
  ]);
  await userRef.set(
    {
      uid,
      phoneNumber,
      phone: phoneNumber,
      whatsappNumber: phoneNumber,
      whatsappVerified: true,
      whatsappVerifiedAt: now,
      authProvider: "whatsapp_otp_test",
      roles: Array.from(roles),
      role,
      activeRole: existing.get("activeRole") ?? role,
      displayName: existing.get("displayName") ?? "",
      email: existing.get("email") ?? null,
      isActive: true,
      createdAt: existing.exists ? existing.get("createdAt") ?? now : now,
      updatedAt: now,
      lastLoginAt: now,
    },
    { merge: true },
  );
}

async function handleSendWhatsAppOtp(request: { data?: unknown }) {
  const data = (request.data ?? {}) as Record<string, unknown>;
  const phone = normalizePhone(data.phoneNumber);
  const role = normalizeRole(data.role);

  const testMode = isTestMode();
  const testers = allowedTesterDigits();
  console.log(
    "[sendWhatsAppOtp] phoneDigits suffix:", phone.digits.slice(-4),
    "| testMode:", testMode,
    "| allowedTestersCount:", testers.length,
    "| tokenPresent:", !!metaAccessToken.value(),
  );

  try {
    assertTesterAllowed(phone.digits);
  } catch (testerErr) {
    console.error(
      "[sendWhatsAppOtp] tester check failed |",
      testerErr instanceof HttpsError
        ? `code=${testerErr.code} message=${testerErr.message}`
        : String(testerErr),
    );
    throw testerErr;
  }
  console.log("[sendWhatsAppOtp] tester check passed");

  const sessionRef = db.collection(otpCollection).doc(sessionIdFor(phone.digits));
  const existing = await sessionRef.get();
  const existingCreatedAt = existing.get("createdAt") as
    | admin.firestore.Timestamp
    | undefined;
  if (
    existingCreatedAt &&
    Date.now() - existingCreatedAt.toMillis() < minRequestSpacingMs
  ) {
    throw new HttpsError(
      "resource-exhausted",
      "Please wait before requesting another code.",
    );
  }

  const code = generateOtp();
  let providerStatus: string;
  try {
    providerStatus = await sendMetaWhatsAppText(phone.digits, code);
  } catch (sendErr) {
    if (sendErr instanceof HttpsError) {
      console.error("[sendWhatsAppOtp] sendMeta threw HttpsError | code:", sendErr.code, "| message:", sendErr.message);
      throw sendErr;
    }
    console.error("[sendWhatsAppOtp] sendMeta threw unexpected error:", String(sendErr));
    throw new HttpsError("unavailable", "WhatsApp provider request failed. Check backend logs.");
  }

  const now = admin.firestore.Timestamp.now();
  await sessionRef.set({
    id: sessionRef.id,
    phoneNumber: phone.e164,
    normalizedPhoneNumber: phone.digits,
    role,
    provider: "meta_whatsapp_cloud_api",
    providerStatus,
    phoneNumberId:
      process.env.META_WHATSAPP_PHONE_NUMBER_ID ?? defaultPhoneNumberId,
    businessAccountId:
      process.env.META_WHATSAPP_BUSINESS_ACCOUNT_ID ?? defaultBusinessAccountId,
    otpHash: otpHash(phone.digits, code),
    expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + expiryMs),
    attempts: 0,
    maxAttempts,
    verified: false,
    createdAt: now,
    updatedAt: now,
    verifiedAt: null,
  });

  console.log("[sendWhatsAppOtp] session stored | providerStatus:", providerStatus);
  return {
    sessionId: sessionRef.id,
    success: true,
    message: "WhatsApp verification code sent.",
  };
}

async function handleVerifyWhatsAppOtp(request: { data?: unknown }) {
  const data = (request.data ?? {}) as Record<string, unknown>;
  const phone = normalizePhone(data.phoneNumber);
  const role = normalizeRole(data.role);
  const code = normalizeCode(data.otpCode ?? data.code);
  assertTesterAllowed(phone.digits);

  const sessionRef = db.collection(otpCollection).doc(sessionIdFor(phone.digits));
  const session = await sessionRef.get();
  if (!session.exists) {
    throw new HttpsError("not-found", "Verification code was not requested.");
  }

  const sessionData = session.data() ?? {};
  const attempts = Number(sessionData.attempts ?? 0);
  const expiresAt = sessionData.expiresAt as
    | admin.firestore.Timestamp
    | undefined;
  const max = Number(sessionData.maxAttempts ?? maxAttempts);
  if (!expiresAt || expiresAt.toMillis() < Date.now()) {
    await sessionRef.set(
      { verified: false, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true },
    );
    throw new HttpsError("deadline-exceeded", "Verification code expired.");
  }
  if (attempts >= max) {
    throw new HttpsError(
      "resource-exhausted",
      "Too many verification attempts.",
    );
  }

  const expectedHash = String(sessionData.otpHash ?? "");
  if (otpHash(phone.digits, code) !== expectedHash) {
    await sessionRef.set(
      {
        attempts: attempts + 1,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    throw new HttpsError(
      "permission-denied",
      "Verification code is incorrect.",
    );
  }

  await sessionRef.set(
    {
      attempts: attempts + 1,
      verified: true,
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  const uid = `phone:${phone.e164}`;
  await upsertUserProfile(uid, phone.e164, role);
  const customToken = await issueCustomToken(phone.e164, role);
  return {
    success: true,
    customToken,
    profile: {
      uid,
      phoneNumber: phone.e164,
      whatsappNumber: phone.e164,
      whatsappVerified: true,
      authProvider: "whatsapp_otp_test",
      activeRole: role,
    },
  };
}

export const sendWhatsAppOtp = onCall(
  { secrets: [metaAccessToken] },
  handleSendWhatsAppOtp,
);

export const requestWhatsAppOtp = onCall(
  { secrets: [metaAccessToken] },
  handleSendWhatsAppOtp,
);

export const verifyWhatsAppOtp = onCall(
  { secrets: [metaAccessToken] },
  handleVerifyWhatsAppOtp,
);
