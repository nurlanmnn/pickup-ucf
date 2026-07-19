import { assertEquals, assertStringIncludes } from "jsr:@std/assert";
import {
  apnsBaseUrl,
  handler,
  isAuthorized,
  sendToUserDevices,
  type OutboxRow,
} from "./index.ts";

const CRON_SECRET = "test-cron-secret";

function setTestEnv(overrides: Record<string, string> = {}) {
  const defaults: Record<string, string> = {
    CRON_SECRET,
    SUPABASE_URL: "https://example.supabase.co",
    SUPABASE_SERVICE_ROLE_KEY: "service-role-key",
    APNS_BUNDLE_ID: "edu.ucf.pickup",
    APNS_KEY_ID: "TESTKEYID",
    APNS_TEAM_ID: "TEAMID",
    APNS_PRIVATE_KEY: "unused-in-these-tests",
    ...overrides,
  };

  for (const [key, value] of Object.entries(defaults)) {
    Deno.env.set(key, value);
  }
}

function authRequest(secret = CRON_SECRET): Request {
  return new Request("https://example.supabase.co/functions/v1/send-push", {
    method: "POST",
    headers: { Authorization: `Bearer ${secret}` },
  });
}

type QueryResult<T> = { data: T | null; error: null | { message: string } };

function createMockSupabase(options: {
  pending?: OutboxRow[];
  tokensByUser?: Record<string, { apns_token: string }[]>;
  fetchError?: { message: string };
  onDeleteToken?: (token: string) => void;
  onMarkSent?: (id: string) => void;
}) {
  const deletedTokens: string[] = [];
  const markedSent: string[] = [];

  const supabase = {
    from(table: string) {
      if (table === "notification_outbox") {
        return {
          select: () => ({
            is: () => ({
              order: () => ({
                limit: (): Promise<QueryResult<OutboxRow[]>> => {
                  if (options.fetchError) {
                    return Promise.resolve({ data: null, error: options.fetchError });
                  }
                  return Promise.resolve({
                    data: options.pending ?? [],
                    error: null,
                  });
                },
              }),
            }),
          }),
          update: (values: { sent_at: string }) => ({
            eq: (_column: string, id: string) => {
              markedSent.push(id);
              options.onMarkSent?.(id);
              return Promise.resolve({ data: null, error: null });
            },
          }),
        };
      }

      if (table === "device_tokens") {
        return {
          select: (_columns: string) => ({
            eq: (_column: string, userId: string) =>
              Promise.resolve({
                data: options.tokensByUser?.[userId] ?? [],
                error: null,
              }),
          }),
          delete: () => ({
            eq: (_column: string, token: string) => {
              deletedTokens.push(token);
              options.onDeleteToken?.(token);
              return Promise.resolve({ data: null, error: null });
            },
          }),
        };
      }

      throw new Error(`Unexpected table: ${table}`);
    },
  };

  return { supabase, deletedTokens, markedSent };
}

Deno.test("isAuthorized rejects missing or invalid bearer token", () => {
  const req = authRequest("wrong-secret");
  assertEquals(isAuthorized(req, CRON_SECRET), false);
  assertEquals(isAuthorized(authRequest(), undefined), false);
});

Deno.test("apnsBaseUrl uses sandbox host when APNS_ENV=sandbox", () => {
  setTestEnv({ APNS_ENV: "sandbox" });
  assertEquals(apnsBaseUrl(), "https://api.sandbox.push.apple.com");

  Deno.env.set("APNS_ENV", "production");
  assertEquals(apnsBaseUrl(), "https://api.push.apple.com");
});

Deno.test("handler returns 401 without valid CRON_SECRET", async () => {
  setTestEnv();
  const res = await handler(authRequest("bad"), {});
  assertEquals(res.status, 401);
});

Deno.test("handler returns sent:0 when outbox is empty", async () => {
  setTestEnv();
  const { supabase } = createMockSupabase({ pending: [] });
  const res = await handler(authRequest(), { supabase: supabase as never });
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { sent: 0 });
});

Deno.test("handler marks outbox row sent after successful APNs delivery", async () => {
  setTestEnv({ APNS_ENV: "sandbox" });

  const row: OutboxRow = {
    id: "outbox-1",
    user_id: "user-1",
    title: "Session starting soon",
    body: "Your pickup starts in 15 minutes",
    payload: { session_id: "session-1" },
  };

  const { supabase, markedSent } = createMockSupabase({
    pending: [row],
    tokensByUser: { "user-1": [{ apns_token: "device-token-abc" }] },
  });

  const fetchCalls: { url: string; body: string }[] = [];
  const fetchImpl = async (input: string | URL | Request, init?: RequestInit) => {
    fetchCalls.push({
      url: String(input),
      body: String(init?.body ?? ""),
    });
    return new Response(null, { status: 200 });
  };

  const res = await handler(authRequest(), {
    supabase: supabase as never,
    fetchImpl,
    getJwt: async () => "mock-jwt",
  });

  assertEquals(res.status, 200);
  assertEquals(await res.json(), { sent: 1 });
  assertEquals(markedSent, ["outbox-1"]);
  assertEquals(fetchCalls.length, 1);
  assertEquals(
    fetchCalls[0].url,
    "https://api.sandbox.push.apple.com/3/device/device-token-abc",
  );
  assertStringIncludes(fetchCalls[0].body, "Session starting soon");
  assertStringIncludes(fetchCalls[0].body, "pickupucf://session/session-1");
});

Deno.test("sendToUserDevices includes open_chat for chat_message notifications", async () => {
  setTestEnv({ APNS_ENV: "sandbox" });

  const row: OutboxRow = {
    id: "outbox-chat",
    user_id: "user-chat",
    title: "New message",
    body: "Someone: hello",
    type: "chat_message",
    payload: { session_id: "session-chat", open_chat: true },
  };

  const { supabase } = createMockSupabase({
    tokensByUser: { "user-chat": [{ apns_token: "chat-token" }] },
  });

  let body = "";
  const fetchImpl = async (_input: string | URL | Request, init?: RequestInit) => {
    body = String(init?.body ?? "");
    return new Response(null, { status: 200 });
  };

  const ok = await sendToUserDevices(supabase as never, row, {
    fetchImpl,
    getJwt: async () => "mock-jwt",
  });

  assertEquals(ok, true);
  assertStringIncludes(body, "pickupucf://session/session-chat");
  assertStringIncludes(body, '"open_chat":true');
});

Deno.test("sendToUserDevices deletes stale tokens on APNs 410", async () => {
  setTestEnv({ APNS_ENV: "production" });

  const row: OutboxRow = {
    id: "outbox-2",
    user_id: "user-2",
    title: "Cancelled",
    body: "Session was cancelled",
  };

  const { supabase, deletedTokens } = createMockSupabase({
    tokensByUser: {
      "user-2": [
        { apns_token: "stale-token" },
        { apns_token: "valid-token" },
      ],
    },
  });

  const fetchImpl = async (input: string | URL | Request) => {
    const url = String(input);
    if (url.includes("stale-token")) {
      return new Response(null, { status: 410 });
    }
    return new Response(null, { status: 200 });
  };

  const ok = await sendToUserDevices(supabase as never, row, {
    fetchImpl,
    getJwt: async () => "mock-jwt",
  });

  assertEquals(ok, true);
  assertEquals(deletedTokens, ["stale-token"]);
});

Deno.test("sendToUserDevices marks processed when user has no device tokens", async () => {
  setTestEnv();
  const row: OutboxRow = {
    id: "outbox-3",
    user_id: "user-3",
    title: "No devices",
    body: "Nothing to deliver",
  };

  const { supabase } = createMockSupabase({ tokensByUser: {} });
  const fetchImpl = () => {
    throw new Error("fetch should not be called when there are no tokens");
  };

  const ok = await sendToUserDevices(supabase as never, row, {
    fetchImpl,
    getJwt: async () => "mock-jwt",
  });

  assertEquals(ok, true);
});
