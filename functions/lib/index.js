"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.verifyWhatsAppOtp = exports.requestWhatsAppOtp = exports.sendWhatsAppOtp = void 0;
const crypto = __importStar(require("crypto"));
const admin = __importStar(require("firebase-admin"));
const params_1 = require("firebase-functions/params");
const https_1 = require("firebase-functions/v2/https");
admin.initializeApp();
const db = admin.firestore();
const otpCollection = "whatsappOtpSessions";
const usersCollection = "users";
const maxAttempts = 5;
const expiryMs = 5 * 60 * 1000;
const minRequestSpacingMs = 60 * 1000;
const defaultPhoneNumberId = "1137966846065788";
const defaultBusinessAccountId = "934349259649903";
const metaAccessToken = (0, params_1.defineSecret)("META_WHATSAPP_ACCESS_TOKEN");
function normalizePhone(raw) {
    if (typeof raw !== "string") {
        throw new https_1.HttpsError("invalid-argument", "Phone number is required.");
    }
    const trimmed = raw.trim();
    const digits = trimmed.replace(/[^\d]/g, "");
    if (!/^[1-9]\d{7,14}$/.test(digits)) {
        throw new https_1.HttpsError("invalid-argument", "Phone number must include country code, for example +961...");
    }
    return { e164: `+${digits}`, digits };
}
function normalizeRole(raw) {
    if (raw === "customer" ||
        raw === "worker" ||
        raw === "storeOwner" ||
        raw === "owner") {
        return raw;
    }
    return "customer";
}
function normalizeCode(raw) {
    const code = String(raw ?? "").trim();
    if (!/^\d{6}$/.test(code)) {
        throw new https_1.HttpsError("invalid-argument", "Verification code must be 6 digits.");
    }
    return code;
}
function isTestMode() {
    return (process.env.WHATSAPP_OTP_TEST_MODE ?? "true").toLowerCase() !==
        "false";
}
function allowedTesterDigits() {
    return (process.env.WHATSAPP_OTP_ALLOWED_TESTERS ?? "")
        .split(",")
        .map((entry) => entry.replace(/[^\d]/g, ""))
        .filter((entry) => entry.length > 0);
}
function assertTesterAllowed(phoneDigits) {
    if (!isTestMode())
        return;
    const testers = allowedTesterDigits();
    if (testers.length === 0) {
        throw new https_1.HttpsError("failed-precondition", "WhatsApp OTP test numbers are not configured yet. Please contact OMW admin.");
    }
    if (!testers.includes(phoneDigits)) {
        throw new https_1.HttpsError("permission-denied", "This WhatsApp number is not enabled for testing yet.");
    }
}
function sessionIdFor(phoneDigits) {
    return crypto.createHash("sha256").update(phoneDigits).digest("hex");
}
function otpHash(phoneDigits, code) {
    return crypto
        .createHash("sha256")
        .update(`${phoneDigits}:${code}:omw-whatsapp-otp-v1`)
        .digest("hex");
}
function generateOtp() {
    const value = crypto.randomInt(0, 1000000);
    return value.toString().padStart(6, "0");
}
async function sendMetaWhatsAppText(phoneDigits, code) {
    const token = metaAccessToken.value();
    if (!token) {
        throw new https_1.HttpsError("failed-precondition", "WhatsApp OTP provider is not configured.");
    }
    const phoneNumberId = process.env.META_WHATSAPP_PHONE_NUMBER_ID ?? defaultPhoneNumberId;
    const response = await fetch(`https://graph.facebook.com/v20.0/${phoneNumberId}/messages`, {
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
    });
    const body = (await response.json().catch(() => ({})));
    if (!response.ok) {
        throw new https_1.HttpsError("unavailable", body.error?.message ??
            "Meta WhatsApp could not send the verification code.");
    }
    return body.messages?.[0]?.message_status ?? "accepted";
}
async function issueCustomToken(phoneNumber, role) {
    const uid = `phone:${phoneNumber}`;
    await admin
        .auth()
        .updateUser(uid, { phoneNumber })
        .catch(async (error) => {
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
async function upsertUserProfile(uid, phoneNumber, role) {
    const now = admin.firestore.FieldValue.serverTimestamp();
    const userRef = db.collection(usersCollection).doc(uid);
    const existing = await userRef.get();
    const roles = new Set([
        ...(existing.get("roles") ?? []),
        role,
    ]);
    await userRef.set({
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
    }, { merge: true });
}
async function handleSendWhatsAppOtp(request) {
    const data = (request.data ?? {});
    const phone = normalizePhone(data.phoneNumber);
    const role = normalizeRole(data.role);
    assertTesterAllowed(phone.digits);
    const sessionRef = db.collection(otpCollection).doc(sessionIdFor(phone.digits));
    const existing = await sessionRef.get();
    const existingCreatedAt = existing.get("createdAt");
    if (existingCreatedAt &&
        Date.now() - existingCreatedAt.toMillis() < minRequestSpacingMs) {
        throw new https_1.HttpsError("resource-exhausted", "Please wait before requesting another code.");
    }
    const code = generateOtp();
    const providerStatus = await sendMetaWhatsAppText(phone.digits, code);
    const now = admin.firestore.Timestamp.now();
    await sessionRef.set({
        id: sessionRef.id,
        phoneNumber: phone.e164,
        normalizedPhoneNumber: phone.digits,
        role,
        provider: "meta_whatsapp_cloud_api",
        providerStatus,
        phoneNumberId: process.env.META_WHATSAPP_PHONE_NUMBER_ID ?? defaultPhoneNumberId,
        businessAccountId: process.env.META_WHATSAPP_BUSINESS_ACCOUNT_ID ?? defaultBusinessAccountId,
        otpHash: otpHash(phone.digits, code),
        expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + expiryMs),
        attempts: 0,
        maxAttempts,
        verified: false,
        createdAt: now,
        updatedAt: now,
        verifiedAt: null,
    });
    return {
        sessionId: sessionRef.id,
        success: true,
        message: "WhatsApp verification code sent.",
    };
}
async function handleVerifyWhatsAppOtp(request) {
    const data = (request.data ?? {});
    const phone = normalizePhone(data.phoneNumber);
    const role = normalizeRole(data.role);
    const code = normalizeCode(data.otpCode ?? data.code);
    assertTesterAllowed(phone.digits);
    const sessionRef = db.collection(otpCollection).doc(sessionIdFor(phone.digits));
    const session = await sessionRef.get();
    if (!session.exists) {
        throw new https_1.HttpsError("not-found", "Verification code was not requested.");
    }
    const sessionData = session.data() ?? {};
    const attempts = Number(sessionData.attempts ?? 0);
    const expiresAt = sessionData.expiresAt;
    const max = Number(sessionData.maxAttempts ?? maxAttempts);
    if (!expiresAt || expiresAt.toMillis() < Date.now()) {
        await sessionRef.set({ verified: false, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
        throw new https_1.HttpsError("deadline-exceeded", "Verification code expired.");
    }
    if (attempts >= max) {
        throw new https_1.HttpsError("resource-exhausted", "Too many verification attempts.");
    }
    const expectedHash = String(sessionData.otpHash ?? "");
    if (otpHash(phone.digits, code) !== expectedHash) {
        await sessionRef.set({
            attempts: attempts + 1,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        throw new https_1.HttpsError("permission-denied", "Verification code is incorrect.");
    }
    await sessionRef.set({
        attempts: attempts + 1,
        verified: true,
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
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
exports.sendWhatsAppOtp = (0, https_1.onCall)({ secrets: [metaAccessToken] }, handleSendWhatsAppOtp);
exports.requestWhatsAppOtp = (0, https_1.onCall)({ secrets: [metaAccessToken] }, handleSendWhatsAppOtp);
exports.verifyWhatsAppOtp = (0, https_1.onCall)({ secrets: [metaAccessToken] }, handleVerifyWhatsAppOtp);
