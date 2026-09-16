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
  const deletedTokens: string[] = [];

  const supabase = {
    from(table: string) {
      if (table !== "live_activity_tokens") {
        throw new Error(`Unexpected table: ${table}`);
      }

      return {
        select: () => ({
          is: () => ({
            lte: () => ({
              order: () => ({
                limit: (): Promise<QueryResult<LiveActivityRow[]>> =>
                  Promise.resolve({ data: rows, error: null }),
              }),
            }),
          }),
        }),
        update: (_values: { ended_at: string }) => ({
          eq: (_column: string, token: string) => {
            markedEnded.push(token);
            return Promise.resolve({ data: null, error: null });
          },
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

  return { supabase, markedEnded, deletedTokens };
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
