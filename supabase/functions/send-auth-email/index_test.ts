import { assertEquals, assertStringIncludes } from "jsr:@std/assert";
import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";
import { handler } from "./index.ts";

const secret = btoa("synthetic-signing-secret-for-tests");
const redirect = "https://pickup-ucf-privacy.vercel.app/auth/reset-password";

async function requestRecovery(overrides: Record<string, string> = {}) {
  Deno.env.set("BREVO_API_KEY", "synthetic-key");
  Deno.env.set("BREVO_SENDER_EMAIL", "sender@example.invalid");
  Deno.env.set("SEND_EMAIL_HOOK_SECRET", secret);
  Deno.env.set("SUPABASE_URL", "https://synthetic.supabase.co");
  const body = JSON.stringify({
    user: { email: "student@ucf.edu" },
    email_data: {
      token: "123456",
      token_hash: "synthetic-token-hash",
      redirect_to: redirect,
      site_url: "pickupucf://auth/confirm",
      email_action_type: "recovery",
      ...overrides,
    },
  });
  const timestamp = new Date();
  const signature = new Webhook(secret).sign(
    "synthetic-request",
    timestamp,
    body,
  );
  let sent: { htmlContent: string; textContent: string } | undefined;
  const originalFetch = globalThis.fetch;
  globalThis.fetch = (_input, init) => {
    sent = JSON.parse(String(init?.body));
    return Promise.resolve(new Response("{}", { status: 201 }));
  };
  try {
    const response = await handler(
      new Request("https://synthetic.invalid/hook", {
        method: "POST",
        body,
        headers: {
          "webhook-id": "synthetic-request",
          "webhook-timestamp": String(Math.floor(timestamp.getTime() / 1000)),
          "webhook-signature": signature,
        },
      }),
    );
    return { response, sent };
  } finally {
    globalThis.fetch = originalFetch;
  }
}

Deno.test("recovery email verifies with provider before redirecting to app", async () => {
  const { response, sent } = await requestRecovery();
  assertEquals(response.status, 200);
  const link = new URL(sent!.textContent.match(/https:\/\/\S+/)![0]);
  assertEquals(link.origin, "https://synthetic.supabase.co");
  assertEquals(link.pathname, "/auth/v1/verify");
  assertEquals(link.searchParams.get("token"), "synthetic-token-hash");
  assertEquals(link.searchParams.get("type"), "recovery");
  assertEquals(link.searchParams.get("redirect_to"), redirect);
  assertStringIncludes(sent!.htmlContent, "&amp;");
});

Deno.test("recovery without token hash fails before sending email", async () => {
  const { response, sent } = await requestRecovery({ token_hash: "" });
  assertEquals(response.status, 500);
  assertEquals(sent, undefined);
});

Deno.test("recovery rejects an unapproved redirect before sending credentials", async () => {
  const { response, sent } = await requestRecovery({
    redirect_to: "https://attacker.invalid/reset",
  });
  assertEquals(response.status, 500);
  assertEquals(sent, undefined);
});
