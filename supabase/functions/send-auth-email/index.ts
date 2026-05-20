import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";

const BREVO_API_URL = "https://api.brevo.com/v3/smtp/email";

const UCF_SUFFIXES = ["@ucf.edu", "@knights.ucf.edu"];

const SEND_ACTIONS = new Set([
  "signup",
  "recovery",
  "email_change",
  "magiclink",
  "email_change_new",
  "reauthentication",
]);

function isUCFEmail(email: string): boolean {
  const lower = email.toLowerCase().trim();
  return UCF_SUFFIXES.some((suffix) => lower.endsWith(suffix));
}

interface EmailData {
  token: string;
  token_hash: string;
  redirect_to: string;
  email_action_type: string;
  site_url: string;
}

interface SendEmailHookPayload {
  user: { email: string };
  email_data?: EmailData;
  email?: EmailData;
}

function otpExpiryMinutes(): number {
  const seconds = Number(Deno.env.get("OTP_EXPIRY_SECONDS") ?? "300");
  return Math.max(1, Math.round(seconds / 60));
}

function hookSigningSecret(): string | null {
  const raw = Deno.env.get("SEND_EMAIL_HOOK_SECRET")?.trim();
  if (!raw) return null;
  return raw.replace(/^v1,whsec_/, "");
}

function webhookHeaders(req: Request): Record<string, string> {
  return {
    "webhook-id": req.headers.get("webhook-id") ?? "",
    "webhook-timestamp": req.headers.get("webhook-timestamp") ?? "",
    "webhook-signature": req.headers.get("webhook-signature") ?? "",
  };
}

function emailDataFrom(payload: SendEmailHookPayload): EmailData | null {
  return payload.email_data ?? payload.email ?? null;
}

function verifyPayload(body: string, req: Request): SendEmailHookPayload {
  const signingSecret = hookSigningSecret();
  if (!signingSecret) {
    throw new Error("SEND_EMAIL_HOOK_SECRET is not set");
  }

  const headers = webhookHeaders(req);
  return new Webhook(signingSecret).verify(body, headers) as SendEmailHookPayload;
}

function jsonResponse(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const apiKey = Deno.env.get("BREVO_API_KEY");
  const senderEmail = Deno.env.get("BREVO_SENDER_EMAIL");
  const senderName = Deno.env.get("BREVO_SENDER_NAME") ?? "PickUp UCF";

  if (!apiKey || !senderEmail) {
    console.error("send-auth-email: missing BREVO_API_KEY or BREVO_SENDER_EMAIL");
    return jsonResponse({ error: "Email service not configured" }, 500);
  }

  const body = await req.text();
  let payload: SendEmailHookPayload;

  try {
    payload = verifyPayload(body, req);
  } catch (error) {
    console.error("send-auth-email: hook verification failed", error);
    console.error("send-auth-email: webhook headers present", {
      id: Boolean(req.headers.get("webhook-id")),
      timestamp: Boolean(req.headers.get("webhook-timestamp")),
      signature: Boolean(req.headers.get("webhook-signature")),
    });
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  const email = payload.user?.email?.toLowerCase().trim() ?? "";
  const data = emailDataFrom(payload);
  const action = data?.email_action_type ?? "";
  const otp = (data?.token ?? "").trim();

  console.log("send-auth-email: received", { action, emailDomain: email.split("@")[1] ?? "" });

  if (!email || !data) {
    console.error("send-auth-email: missing user email or email_data");
    return jsonResponse({ error: "Invalid payload" }, 400);
  }

  if (!isUCFEmail(email)) {
    console.error("send-auth-email: rejected non-UCF email", email);
    return jsonResponse({ error: "UCF email required" }, 400);
  }

  if (!SEND_ACTIONS.has(action)) {
    console.log("send-auth-email: ignored action", action);
    return jsonResponse({}, 200);
  }

  const expiryMinutes = otpExpiryMinutes();

  let subject: string;
  let htmlContent: string;
  let textContent: string;

  if (action === "signup" || action === "magiclink") {
    subject = "Your PickUp UCF verification code";
    htmlContent = `
      <p>Welcome to PickUp UCF. Enter this code in the app to verify your email:</p>
      <p style="font-size:32px;font-weight:bold;letter-spacing:6px;margin:24px 0;">${otp}</p>
      <p>This code expires in <strong>${expiryMinutes} minutes</strong>.</p>
      <p>If you did not create an account, you can ignore this email.</p>
    `;
    textContent =
      `Your PickUp UCF verification code is ${otp}. It expires in ${expiryMinutes} minutes.`;
  } else if (action === "recovery") {
    const confirmUrl =
      data.redirect_to ||
      `${data.site_url}?token=${data.token_hash}&type=${action}`;
    subject = "Reset your PickUp UCF password";
    htmlContent = `
      <p>Reset your PickUp UCF password using this link:</p>
      <p><a href="${confirmUrl}">Reset password</a></p>
      <p>Or enter this code in the app if prompted: <strong>${otp}</strong></p>
      <p>This link/code expires in <strong>${expiryMinutes} minutes</strong>.</p>
    `;
    textContent = `Reset your password: ${confirmUrl}\nCode: ${otp}`;
  } else {
    subject = "Your PickUp UCF verification code";
    htmlContent = `
      <p>Your PickUp UCF verification code:</p>
      <p style="font-size:32px;font-weight:bold;letter-spacing:6px;margin:24px 0;">${otp}</p>
      <p>This code expires in <strong>${expiryMinutes} minutes</strong>.</p>
    `;
    textContent = `Your PickUp UCF verification code is ${otp}.`;
  }

  if (!otp) {
    console.error("send-auth-email: empty OTP token for action", action);
    return jsonResponse({ error: "Missing OTP token" }, 500);
  }

  const brevoRes = await fetch(BREVO_API_URL, {
    method: "POST",
    headers: {
      "api-key": apiKey,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify({
      sender: { name: senderName, email: senderEmail },
      to: [{ email }],
      subject,
      htmlContent,
      textContent,
    }),
  });

  if (!brevoRes.ok) {
    const errText = await brevoRes.text();
    console.error("send-auth-email: Brevo error", brevoRes.status, errText);
    return jsonResponse({ error: "Failed to send email" }, 500);
  }

  console.log("send-auth-email: sent via Brevo", { action, emailDomain: email.split("@")[1] ?? "" });
  return jsonResponse({}, 200);
});
