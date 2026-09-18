import { assertEquals, assertStringIncludes } from "jsr:@std/assert";
import {
  apnsBaseUrl,
  createCachedJwtProvider,
  handler,
  isAuthorized,
  type LiveActivityRow,
  type OutboxRow,
  sendToUserDevices,
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
  liveActivities?: LiveActivityRow[];
  fetchError?: { message: string };
  onSelectTokens?: (userId: string) => void;
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
                    return Promise.resolve({
                      data: null,
                      error: options.fetchError,
                    });
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
            eq: (_column: string, userId: string) => {
              options.onSelectTokens?.(userId);
              return Promise.resolve({
                data: options.tokensByUser?.[userId] ?? [],
                error: null,
              });
            },
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

      if (table === "live_activity_tokens") {
        return {
          select: () => ({
            is: () => ({
              lte: () => ({
                order: () => ({
                  limit: () =>
                    Promise.resolve({
                      data: options.liveActivities ?? [],
                      error: null,
                    }),
                }),
              }),
            }),
          }),
          update: () => ({
            eq: () => Promise.resolve({ data: null, error: null }),
          }),
          delete: () => ({
            eq: () => Promise.resolve({ data: null, error: null }),
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

Deno.test("APNs provider JWT is reused and refreshed inside Apple's safe window", async () => {
  let now = 1_000_000;
  let generations = 0;
  const getJwt = createCachedJwtProvider(
    async () => `jwt-${++generations}`,
    () => now,
  );

  assertEquals(await getJwt(), "jwt-1");
  now += 20 * 60 * 1000;
  assertEquals(await getJwt(), "jwt-1");
  now += 30 * 60 * 1000;
  assertEquals(await getJwt(), "jwt-2");
  assertEquals(generations, 2);
});

Deno.test("handler returns 401 without valid CRON_SECRET", async () => {
  setTestEnv();
  const res = await handler(authRequest("bad"), {});
  assertEquals(res.status, 401);
});

Deno.test("handler returns zero counts when all queues are empty", async () => {
  setTestEnv();
  const { supabase } = createMockSupabase({ pending: [] });
  const res = await handler(authRequest(), { supabase: supabase as never });
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { sent: 0, liveActivitiesEnded: 0 });
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
  const fetchImpl = async (
    input: string | URL | Request,
    init?: RequestInit,
  ) => {
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
  assertEquals(await res.json(), { sent: 1, liveActivitiesEnded: 0 });
  assertEquals(markedSent, ["outbox-1"]);
  assertEquals(fetchCalls.length, 1);
  assertEquals(
    fetchCalls[0].url,
    "https://api.sandbox.push.apple.com/3/device/device-token-abc",
  );
  assertStringIncludes(fetchCalls[0].body, "Session starting soon");
  assertStringIncludes(fetchCalls[0].body, "pickupucf://session/session-1");
});

Deno.test("handler shares one APNs provider JWT across the full batch", async () => {
  setTestEnv({ APNS_ENV: "production" });
  const rows: OutboxRow[] = [
    {
      id: "outbox-batch-1",
      user_id: "user-batch-1",
      title: "First",
      body: "First notification",
    },
    {
      id: "outbox-batch-2",
      user_id: "user-batch-2",
      title: "Second",
      body: "Second notification",
    },
  ];
  const { supabase } = createMockSupabase({
    pending: rows,
    tokensByUser: {
      "user-batch-1": [{ apns_token: "device-batch-1" }],
      "user-batch-2": [{ apns_token: "device-batch-2" }],
    },
  });
  let jwtGenerations = 0;

  const res = await handler(authRequest(), {
    supabase: supabase as never,
    fetchImpl: () => Promise.resolve(new Response(null, { status: 200 })),
    getJwt: () => Promise.resolve(`jwt-${++jwtGenerations}`),
  });

  assertEquals(res.status, 200);
  assertEquals(jwtGenerations, 1);
});

Deno.test("handler ends due Live Activities when the notification outbox is empty", async () => {
  setTestEnv({ APNS_ENV: "sandbox" });
  const { supabase } = createMockSupabase({
    pending: [],
    liveActivities: [{
      apns_token: "live-token",
      starts_at: "2023-11-14T22:13:20.000Z",
      ends_at: "2023-11-14T23:43:20.000Z",
    }],
  });

  const res = await handler(authRequest(), {
    supabase: supabase as never,
    now: () => new Date("2023-11-14T23:44:00.000Z"),
    fetchImpl: () => Promise.resolve(new Response(null, { status: 200 })),
    getJwt: () => Promise.resolve("mock-jwt"),
  });

  assertEquals(res.status, 200);
  assertEquals(await res.json(), { sent: 0, liveActivitiesEnded: 1 });
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
  const fetchImpl = async (
    _input: string | URL | Request,
    init?: RequestInit,
  ) => {
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

Deno.test("chat previews are sent only to the outbox user's current tokens", async () => {
  setTestEnv({ APNS_ENV: "sandbox" });
  const selectedUsers: string[] = [];
  const row: OutboxRow = {
    id: "outbox-account-switch",
    user_id: "user-b",
    title: "New message",
    body: "Teammate: private preview",
    type: "chat_message",
    payload: { session_id: "session-private" },
  };
  const { supabase } = createMockSupabase({
    tokensByUser: {
      "user-a": [{ apns_token: "old-owner-token" }],
      "user-b": [{ apns_token: "current-owner-token" }],
    },
    onSelectTokens: (userId) => selectedUsers.push(userId),
  });
  const requests: { url: string; body: string }[] = [];

  const delivered = await sendToUserDevices(supabase as never, row, {
    getJwt: () => Promise.resolve("mock-jwt"),
    fetchImpl: (input, init) => {
      requests.push({ url: String(input), body: String(init?.body ?? "") });
      return Promise.resolve(new Response(null, { status: 200 }));
    },
  });

  assertEquals(delivered, true);
  assertEquals(selectedUsers, ["user-b"]);
  assertEquals(requests.length, 1);
  assertStringIncludes(requests[0].url, "current-owner-token");
  assertStringIncludes(requests[0].body, "private preview");
});

Deno.test("sendToUserDevices includes calendar cleanup metadata for cancellation notifications", async () => {
  setTestEnv({ APNS_ENV: "sandbox" });

  const row: OutboxRow = {
    id: "outbox-cancelled",
    user_id: "user-cancelled",
    title: "Game cancelled",
    body: "The game was cancelled by the host",
    type: "session_cancelled",
    payload: { session_id: "session-cancelled" },
  };

  const { supabase } = createMockSupabase({
    tokensByUser: { "user-cancelled": [{ apns_token: "cancelled-token" }] },
  });

  const requests: RequestInit[] = [];
  const fetchImpl = (_input: string | URL | Request, init?: RequestInit) => {
    requests.push(init ?? {});
    return Promise.resolve(new Response(null, { status: 200 }));
  };

  const ok = await sendToUserDevices(supabase as never, row, {
    fetchImpl,
    getJwt: () => Promise.resolve("mock-jwt"),
  });

  const backgroundPayload = JSON.parse(String(requests[0].body));
  const alertPayload = JSON.parse(String(requests[1].body));
  assertEquals(ok, true);
  assertEquals(requests.length, 2);
  assertEquals(
    (requests[0].headers as Record<string, string>)["apns-push-type"],
    "background",
  );
  assertEquals(
    (requests[0].headers as Record<string, string>)["apns-priority"],
    "5",
  );
  assertEquals(backgroundPayload.aps, { "content-available": 1 });
  assertEquals(backgroundPayload.notification_type, "session_cancelled");
  assertEquals(backgroundPayload.session_id, "session-cancelled");
  assertEquals(
    (requests[1].headers as Record<string, string>)["apns-push-type"],
    "alert",
  );
  assertEquals(alertPayload.notification_type, "session_cancelled");
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

Deno.test("sendToUserDevices removes an exact token rejected as BadDeviceToken", async () => {
  setTestEnv({ APNS_ENV: "production" });
  const row: OutboxRow = {
    id: "outbox-bad-token",
    user_id: "user-bad-token",
    title: "New chat message",
    body: "Open PickUp UCF to view it.",
    type: "chat_message",
  };
  const failures: { status: number; reason: string }[] = [];
  const { supabase, deletedTokens } = createMockSupabase({
    tokensByUser: {
      "user-bad-token": [{ apns_token: "bad-device-token" }],
    },
  });

  const ok = await sendToUserDevices(supabase as never, row, {
    getJwt: async () => "mock-jwt",
    fetchImpl: async () =>
      new Response(JSON.stringify({ reason: "BadDeviceToken" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      }),
    onAPNsFailure: (failure) => failures.push(failure),
  });

  assertEquals(ok, false);
  assertEquals(deletedTokens, ["bad-device-token"]);
  assertEquals(failures, [{ status: 400, reason: "BadDeviceToken" }]);
});

Deno.test("sendToUserDevices reports a privacy-safe APNs rejection", async () => {
  setTestEnv({ APNS_ENV: "production" });

  const row: OutboxRow = {
    id: "outbox-rejected",
    user_id: "user-rejected",
    title: "New chat message",
    body: "Open PickUp UCF to view it.",
    type: "chat_message",
  };
  const failures: { status: number; reason: string }[] = [];
  const { supabase, markedSent } = createMockSupabase({
    pending: [row],
    tokensByUser: {
      "user-rejected": [{ apns_token: "private-device-token" }],
    },
  });

  const ok = await sendToUserDevices(supabase as never, row, {
    getJwt: async () => "mock-jwt",
    fetchImpl: async () =>
      new Response(JSON.stringify({ reason: "TooManyProviderTokenUpdates" }), {
        status: 429,
        headers: { "Content-Type": "application/json" },
      }),
    onAPNsFailure: (failure) => failures.push(failure),
  });

  assertEquals(ok, false);
  assertEquals(markedSent, []);
  assertEquals(failures, [{
    status: 429,
    reason: "TooManyProviderTokenUpdates",
  }]);
  assertEquals(
    JSON.stringify(failures).includes("private-device-token"),
    false,
  );
});

Deno.test("APNs diagnostics discard unrecognized response text", async () => {
  setTestEnv({ APNS_ENV: "production" });

  const row: OutboxRow = {
    id: "outbox-private-error",
    user_id: "user-private-error",
    title: "New chat message",
    body: "Open PickUp UCF to view it.",
    type: "chat_message",
  };
  const failures: { status: number; reason: string }[] = [];
  const { supabase } = createMockSupabase({
    tokensByUser: {
      "user-private-error": [{ apns_token: "private-device-token" }],
    },
  });

  await sendToUserDevices(supabase as never, row, {
    getJwt: async () => "mock-jwt",
    fetchImpl: async () =>
      new Response(
        JSON.stringify({ reason: "private-device-token@example.com" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      ),
    onAPNsFailure: (failure) => failures.push(failure),
  });

  assertEquals(failures, [{ status: 400, reason: "Unknown" }]);
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
