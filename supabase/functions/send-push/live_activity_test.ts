import { assertEquals } from "jsr:@std/assert";
import {
  appleReferenceDateSeconds,
  type LiveActivityRow,
  sendDueLiveActivities,
} from "./index.ts";

const APPLE_REFERENCE_DATE_OFFSET = 978_307_200;

type QueryResult<T> = { data: T | null; error: null | { message: string } };

function createLiveActivitySupabase(rows: LiveActivityRow[]) {
  const markedEnded: string[] = [];
  const updates: Record<string, unknown>[] = [];
  const deletedTokens: string[] = [];

  const supabase = {
    from(table: string) {
      if (table !== "live_activity_tokens") {
        throw new Error(`Unexpected table: ${table}`);
      }

      return {
        select: () => ({
          is: () => ({
            or: () => ({
              order: () => ({
                limit: (): Promise<QueryResult<LiveActivityRow[]>> =>
                  Promise.resolve({ data: rows, error: null }),
              }),
            }),
          }),
        }),
        update: (values: Record<string, unknown>) => ({
          eq: (_column: string, token: string) => ({
            eq: () => {
              updates.push(values);
              if (values.ended_at) markedEnded.push(token);
              return Promise.resolve({ data: null, error: null });
            },
          }),
        }),
        delete: () => ({
          eq: (_column: string, token: string) => {
            deletedTokens.push(token);
            return Promise.resolve({ data: null, error: null });
          },
        }),
      };
    },
  };

  return { supabase, markedEnded, deletedTokens, updates };
}

Deno.test("appleReferenceDateSeconds matches Swift JSONEncoder Date encoding", () => {
  assertEquals(
    appleReferenceDateSeconds("2023-11-14T22:13:20.000Z"),
    1_700_000_000 - APPLE_REFERENCE_DATE_OFFSET,
  );
});

Deno.test("sendDueLiveActivities sends an immediate ActivityKit end event", async () => {
  Deno.env.set("APNS_ENV", "sandbox");
  Deno.env.set("APNS_BUNDLE_ID", "edu.ucf.pickup");

  const row: LiveActivityRow = {
    updated_at: "2023-11-14T22:00:00.000Z",
    apns_token: "live-token",
    starts_at: "2023-11-14T22:13:20.000Z",
    ends_at: "2023-11-14T23:43:20.000Z",
  };
  const { supabase, markedEnded } = createLiveActivitySupabase([row]);
  const now = new Date("2023-11-14T23:44:00.000Z");
  let requestUrl = "";
  let request: RequestInit | undefined;

  const ended = await sendDueLiveActivities(supabase as never, {
    now: () => now,
    getJwt: () => Promise.resolve("mock-jwt"),
    fetchImpl: (input, init) => {
      requestUrl = String(input);
      request = init;
      return Promise.resolve(new Response(null, { status: 200 }));
    },
  });

  const headers = request?.headers as Record<string, string>;
  const body = JSON.parse(String(request?.body));
  assertEquals(ended, 1);
  assertEquals(markedEnded, ["live-token"]);
  assertEquals(
    requestUrl,
    "https://api.sandbox.push.apple.com/3/device/live-token",
  );
  assertEquals(headers["apns-push-type"], "liveactivity");
  assertEquals(headers["apns-topic"], "edu.ucf.pickup.push-type.liveactivity");
  assertEquals(body.aps.event, "end");
  assertEquals(body.aps.timestamp, Math.floor(now.getTime() / 1000));
  assertEquals(
    body.aps["dismissal-date"],
    Math.floor(now.getTime() / 1000) - 1,
  );
  assertEquals(
    body.aps["content-state"].startsAt,
    appleReferenceDateSeconds(row.starts_at),
  );
  assertEquals(
    body.aps["content-state"].endsAt,
    appleReferenceDateSeconds(row.ends_at),
  );
});

Deno.test("sendDueLiveActivities deletes an expired APNs token after 410", async () => {
  Deno.env.set("APNS_BUNDLE_ID", "edu.ucf.pickup");
  const row: LiveActivityRow = {
    updated_at: "2023-11-14T22:00:00.000Z",
    apns_token: "expired-live-token",
    starts_at: "2023-11-14T22:13:20.000Z",
    ends_at: "2023-11-14T23:43:20.000Z",
  };
  const { supabase, deletedTokens } = createLiveActivitySupabase([row]);

  const ended = await sendDueLiveActivities(supabase as never, {
    now: () => new Date("2023-11-14T23:44:00.000Z"),
    getJwt: () => Promise.resolve("mock-jwt"),
    fetchImpl: () => Promise.resolve(new Response(null, { status: 410 })),
  });

  assertEquals(ended, 0);
  assertEquals(deletedTokens, ["expired-live-token"]);
});

Deno.test("Live Activity gets a silent update at start with canonical dates", async () => {
  const row: LiveActivityRow = {
    apns_token: "starting-token",
    starts_at: "2023-11-14T22:13:20.000Z",
    ends_at: "2023-11-14T23:43:20.000Z",
    updated_at: "2023-11-14T22:00:00.000Z",
  };
  const { supabase, updates, markedEnded } = createLiveActivitySupabase([row]);
  let body: any;
  const count = await sendDueLiveActivities(supabase as never, {
    now: () => new Date(row.starts_at),
    getJwt: () => Promise.resolve("jwt"),
    fetchImpl: (_input, init) => {
      body = JSON.parse(String(init?.body));
      return Promise.resolve(new Response(null, { status: 200 }));
    },
  });
  assertEquals(count, 0);
  assertEquals(body.aps.event, "update");
  assertEquals(body.aps.alert, undefined);
  assertEquals(body.aps["stale-date"], Date.parse(row.ends_at) / 1000);
  assertEquals(updates[0].needs_update, false);
  assertEquals(updates[0].started_at, row.starts_at);
  assertEquals(markedEnded, []);
});

Deno.test("failed Live Activity delivery remains retryable", async () => {
  const row: LiveActivityRow = {
    apns_token: "retry-token",
    starts_at: "2023-11-14T22:13:20.000Z",
    ends_at: "2023-11-14T23:43:20.000Z",
    updated_at: "2023-11-14T22:00:00.000Z",
  };
  const { supabase, updates, deletedTokens } = createLiveActivitySupabase([
    row,
  ]);
  await sendDueLiveActivities(supabase as never, {
    now: () => new Date(row.ends_at),
    getJwt: () => Promise.resolve("jwt"),
    fetchImpl: () => Promise.resolve(new Response(null, { status: 503 })),
  });
  assertEquals(updates, []);
  assertEquals(deletedTokens, []);
});

Deno.test("Live Activity timestamps are timezone-independent and preserve fractions", () => {
  assertEquals(
    appleReferenceDateSeconds("2026-11-01T01:30:00.250-04:00"),
    appleReferenceDateSeconds("2026-11-01T05:30:00.250Z"),
  );
});

Deno.test("one failed device does not block another activity ending", async () => {
  const rows: LiveActivityRow[] = ["failed", "healthy"].map((apns_token) => ({
    apns_token,
    starts_at: "2023-11-14T22:13:20Z",
    ends_at: "2023-11-14T23:43:20Z",
    updated_at: "2023-11-14T22:00:00Z",
  }));
  const { supabase, markedEnded } = createLiveActivitySupabase(rows);
  let requests = 0;
  const ended = await sendDueLiveActivities(supabase as never, {
    now: () => new Date("2023-11-15T00:00:00Z"),
    getJwt: () => Promise.resolve("jwt"),
    fetchImpl: () => {
      if (++requests === 1) {
        return Promise.reject(new Error("network unavailable"));
      }
      return Promise.resolve(new Response(null, { status: 200 }));
    },
  });
  assertEquals(ended, 1);
  assertEquals(markedEnded, ["healthy"]);
});
