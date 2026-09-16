import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "https://esm.sh/jose@5.9.6";

export const BATCH_SIZE = 50;

export interface OutboxRow {
  id: string;
  user_id: string;
  title: string;
  body: string;
  type?: string;
  payload?: { session_id?: string; open_chat?: boolean; message_id?: string };
}

export interface LiveActivityRow {
  apns_token: string;
  starts_at: string;
  ends_at: string;
}

export interface HandlerDeps {
  supabase?: SupabaseClient;
  fetchImpl?: typeof fetch;
  getJwt?: () => Promise<string>;
  now?: () => Date;
}

const APPLE_REFERENCE_DATE_OFFSET_SECONDS = 978_307_200;

export function apnsBaseUrl(): string {
  return Deno.env.get("APNS_ENV") === "sandbox"
    ? "https://api.sandbox.push.apple.com"
    : "https://api.push.apple.com";
}

export function isAuthorized(
  req: Request,
  cronSecret: string | undefined,
): boolean {
  if (!cronSecret) return false;
  const auth = req.headers.get("Authorization") ?? "";
  return auth === `Bearer ${cronSecret}`;
}

export async function apnsJwt(): Promise<string> {
  const key = await importPKCS8(Deno.env.get("APNS_PRIVATE_KEY")!, "ES256");
  return await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: Deno.env.get("APNS_KEY_ID")! })
    .setIssuer(Deno.env.get("APNS_TEAM_ID")!)
    .setIssuedAt()
    .sign(key);
}

export function appleReferenceDateSeconds(isoDate: string): number {
  const unixMilliseconds = Date.parse(isoDate);
  if (!Number.isFinite(unixMilliseconds)) {
    throw new Error(`Invalid Live Activity date: ${isoDate}`);
  }

  return unixMilliseconds / 1000 - APPLE_REFERENCE_DATE_OFFSET_SECONDS;
}

export async function sendDueLiveActivities(
  supabase: SupabaseClient,
  deps: Pick<HandlerDeps, "fetchImpl" | "getJwt" | "now"> = {},
): Promise<number> {
  const fetchImpl = deps.fetchImpl ?? fetch;
  const getJwt = deps.getJwt ?? apnsJwt;
  const now = deps.now?.() ?? new Date();
  const nowIso = now.toISOString();

  const { data: due, error } = await supabase
    .from("live_activity_tokens")
    .select("apns_token, starts_at, ends_at")
    .is("ended_at", null)
    .lte("ends_at", nowIso)
    .order("ends_at", { ascending: true })
    .limit(BATCH_SIZE);

  if (error) throw new Error(error.message);
  if (!due?.length) return 0;

  const jwt = await getJwt();
  const timestamp = Math.floor(now.getTime() / 1000);
  let ended = 0;

  for (const row of due as LiveActivityRow[]) {
    const response = await fetchImpl(
      `${apnsBaseUrl()}/3/device/${row.apns_token}`,
      {
        method: "POST",
        headers: {
          authorization: `bearer ${jwt}`,
          "apns-topic": `${Deno.env.get(
            "APNS_BUNDLE_ID",
          )!}.push-type.liveactivity`,
          "apns-push-type": "liveactivity",
          "apns-priority": "10",
        },
        body: JSON.stringify({
          aps: {
            timestamp,
            event: "end",
            "content-state": {
              startsAt: appleReferenceDateSeconds(row.starts_at),
              endsAt: appleReferenceDateSeconds(row.ends_at),
            },
            "dismissal-date": timestamp - 1,
          },
        }),
      },
    );

    if (response.ok) {
      const { error: updateError } = await supabase
        .from("live_activity_tokens")
        .update({ ended_at: nowIso })
        .eq("apns_token", row.apns_token);
      if (updateError) throw new Error(updateError.message);
      ended++;
    } else if (response.status === 410) {
      const { error: deleteError } = await supabase
        .from("live_activity_tokens")
        .delete()
        .eq("apns_token", row.apns_token);
      if (deleteError) throw new Error(deleteError.message);
    }
  }

  return ended;
}

export async function sendToUserDevices(
  supabase: SupabaseClient,
  row: OutboxRow,
  deps: Pick<HandlerDeps, "fetchImpl" | "getJwt"> = {},
): Promise<boolean> {
  const fetchImpl = deps.fetchImpl ?? fetch;
  const getJwt = deps.getJwt ?? apnsJwt;

  const { data: tokens } = await supabase
    .from("device_tokens")
    .select("apns_token")
    .eq("user_id", row.user_id);

  if (!tokens?.length) return true;

  const jwt = await getJwt();
  const sessionId = row.payload?.session_id;
  const url = sessionId ? `pickupucf://session/${sessionId}` : undefined;
  const openChat = row.payload?.open_chat === true ||
    row.type === "chat_message";
  const isSessionCancellation = row.type === "session_cancelled";

  let anySuccess = false;
  for (const { apns_token } of tokens) {
    const endpoint = `${apnsBaseUrl()}/3/device/${apns_token}`;

    if (isSessionCancellation && sessionId) {
      const backgroundResponse = await fetchImpl(endpoint, {
        method: "POST",
        headers: {
          authorization: `bearer ${jwt}`,
          "apns-topic": Deno.env.get("APNS_BUNDLE_ID")!,
          "apns-push-type": "background",
          "apns-priority": "5",
        },
        body: JSON.stringify({
          aps: { "content-available": 1 },
          session_id: sessionId,
          notification_type: row.type,
        }),
      });

      if (backgroundResponse.status === 410) {
        await supabase.from("device_tokens").delete().eq(
          "apns_token",
          apns_token,
        );
        continue;
      }
    }

    const res = await fetchImpl(
      endpoint,
      {
        method: "POST",
        headers: {
          authorization: `bearer ${jwt}`,
          "apns-topic": Deno.env.get("APNS_BUNDLE_ID")!,
          "apns-push-type": "alert",
          "apns-priority": "10",
        },
        body: JSON.stringify({
          aps: {
            alert: { title: row.title, body: row.body },
            sound: "default",
          },
          ...(url ? { url } : {}),
          ...(sessionId ? { session_id: sessionId } : {}),
          ...(row.type ? { notification_type: row.type } : {}),
          ...(openChat ? { open_chat: true } : {}),
        }),
      },
    );

    if (res.ok) anySuccess = true;
    if (res.status === 410) {
      await supabase.from("device_tokens").delete().eq(
        "apns_token",
        apns_token,
      );
    }
  }

  return anySuccess || !tokens.length;
}

export async function handler(
  req: Request,
  deps: HandlerDeps = {},
): Promise<Response> {
  const cronSecret = Deno.env.get("CRON_SECRET");
  if (!isAuthorized(req, cronSecret)) {
    return new Response("Unauthorized", { status: 401 });
  }

  const supabase = deps.supabase ?? createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: pending, error } = await supabase
    .from("notification_outbox")
    .select("id, user_id, title, body, type, payload")
    .is("sent_at", null)
    .order("created_at", { ascending: true })
    .limit(BATCH_SIZE);

  if (error) return new Response(error.message, { status: 500 });
  let sent = 0;
  for (const row of pending ?? []) {
    const ok = await sendToUserDevices(supabase, row as OutboxRow, deps);
    if (ok) {
      await supabase
        .from("notification_outbox")
        .update({ sent_at: (deps.now?.() ?? new Date()).toISOString() })
        .eq("id", row.id);
      sent++;
    }
  }

  let liveActivitiesEnded: number;
  try {
    liveActivitiesEnded = await sendDueLiveActivities(supabase, deps);
  } catch (liveActivityError) {
    const message = liveActivityError instanceof Error
      ? liveActivityError.message
      : "Failed to process Live Activities";
    return new Response(message, { status: 500 });
  }

  return new Response(JSON.stringify({ sent, liveActivitiesEnded }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}

if (import.meta.main) {
  Deno.serve((req) => handler(req));
}
