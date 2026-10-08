import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "https://esm.sh/jose@5.9.6";

export const BATCH_SIZE = 50;
export const APNS_JWT_REFRESH_INTERVAL_MS = 50 * 60 * 1000;

export interface OutboxRow {
  id: string;
  user_id: string;
  title: string;
  body: string;
  type?: string;
  payload?: {
    session_id?: string;
    open_chat?: boolean;
    message_id?: string;
    session_starts_at?: string;
    session_ends_at?: string;
  };
}

export interface LiveActivityRow {
  apns_token: string;
  updated_at: string;
  starts_at: string;
  ends_at: string;
}

export interface HandlerDeps {
  supabase?: SupabaseClient;
  fetchImpl?: typeof fetch;
  getJwt?: () => Promise<string>;
  now?: () => Date;
  onAPNsFailure?: (failure: APNsFailure) => void;
}

export interface APNsFailure {
  status: number;
  reason: string;
}

const APPLE_REFERENCE_DATE_OFFSET_SECONDS = 978_307_200;
const SAFE_APNS_REASONS = new Set([
  "BadCertificate",
  "BadCertificateEnvironment",
  "BadCollapseId",
  "BadDeviceToken",
  "BadExpirationDate",
  "BadMessageId",
  "BadPriority",
  "BadTopic",
  "DeviceTokenNotForTopic",
  "DuplicateHeaders",
  "ExpiredProviderToken",
  "Forbidden",
  "IdleTimeout",
  "InternalServerError",
  "InvalidProviderToken",
  "InvalidPushType",
  "MissingDeviceToken",
  "MissingProviderToken",
  "MissingTopic",
  "PayloadEmpty",
  "ServiceUnavailable",
  "Shutdown",
  "TooManyProviderTokenUpdates",
  "TooManyRequests",
  "TopicDisallowed",
  "Unregistered",
]);

async function reportAPNsFailure(
  response: Response,
  callback: (failure: APNsFailure) => void,
): Promise<APNsFailure> {
  let reason = "Unknown";
  try {
    const body = await response.json();
    if (
      typeof body === "object" && body !== null &&
      "reason" in body && typeof body.reason === "string" &&
      SAFE_APNS_REASONS.has(body.reason)
    ) {
      reason = body.reason;
    }
  } catch {
    // Keep diagnostics limited to the status and a fixed fallback value.
  }

  const failure = { status: response.status, reason };
  callback(failure);
  return failure;
}

function logAPNsFailure(failure: APNsFailure): void {
  console.warn("send-push: APNs delivery rejected", failure);
}

function isInvalidDeviceToken(failure: APNsFailure): boolean {
  return failure.status === 400 && failure.reason === "BadDeviceToken";
}

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

export function createCachedJwtProvider(
  generateJwt: () => Promise<string> = apnsJwt,
  now: () => number = Date.now,
): () => Promise<string> {
  let cachedJwt: Promise<string> | undefined;
  let generatedAt = 0;

  return async () => {
    const currentTime = now();
    if (
      !cachedJwt ||
      currentTime - generatedAt >= APNS_JWT_REFRESH_INTERVAL_MS
    ) {
      generatedAt = currentTime;
      cachedJwt = generateJwt().catch((error) => {
        cachedJwt = undefined;
        generatedAt = 0;
        throw error;
      });
    }
    return await cachedJwt;
  };
}

const getCachedApnsJwt = createCachedJwtProvider();

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
    .select("apns_token, starts_at, ends_at, updated_at")
    .is("ended_at", null)
    .or(
      `ends_at.lte.${nowIso},needs_update.eq.true,and(starts_at.lte.${nowIso},started_at.is.null)`,
    )
    .order("ends_at", { ascending: true })
    .limit(BATCH_SIZE);

  if (error) throw new Error(error.message);
  if (!due?.length) return 0;

  const jwt = await getJwt();
  const timestamp = Math.floor(now.getTime() / 1000);
  let ended = 0;

  for (const row of due as LiveActivityRow[]) {
    try {
      const isEnded = Date.parse(row.ends_at) <= now.getTime();
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
              event: isEnded ? "end" : "update",
              "content-state": {
                startsAt: appleReferenceDateSeconds(row.starts_at),
                endsAt: appleReferenceDateSeconds(row.ends_at),
              },
              ...(isEnded
                ? { "dismissal-date": timestamp - 1 }
                : { "stale-date": Math.floor(Date.parse(row.ends_at) / 1000) }),
            },
          }),
        },
      );

      if (response.ok) {
        const { error: updateError } = await supabase
          .from("live_activity_tokens")
          .update(
            isEnded ? { ended_at: nowIso, needs_update: false } : {
              needs_update: false,
              started_at: Date.parse(row.starts_at) <= now.getTime()
                ? nowIso
                : null,
            },
          )
          .eq("apns_token", row.apns_token)
          // Do not acknowledge a newer schedule change while APNs was in flight.
          .eq("updated_at", row.updated_at);
        if (updateError) throw new Error(updateError.message);
        if (isEnded) ended++;
      } else {
        const failure = await reportAPNsFailure(response, logAPNsFailure);
        if (response.status !== 410 && !isInvalidDeviceToken(failure)) continue;
        const { error: deleteError } = await supabase
          .from("live_activity_tokens")
          .delete()
          .eq("apns_token", row.apns_token);
        if (deleteError) throw new Error(deleteError.message);
      }
    } catch {
      // A transient failure for one device must not block other due activities.
      console.warn("send-push: Live Activity dispatch failed; will retry");
    }
  }

  return ended;
}

export async function sendToUserDevices(
  supabase: SupabaseClient,
  row: OutboxRow,
  deps: Pick<HandlerDeps, "fetchImpl" | "getJwt" | "onAPNsFailure" | "now"> =
    {},
): Promise<boolean> {
  const fetchImpl = deps.fetchImpl ?? fetch;
  const getJwt = deps.getJwt ?? apnsJwt;
  const onAPNsFailure = deps.onAPNsFailure ?? logAPNsFailure;

  const now = deps.now?.() ?? new Date();
  const isReminder = row.type === "session_reminder_1h" ||
    row.type === "host_session_reminder_1h";
  const startsAt = Date.parse(row.payload?.session_starts_at ?? "");
  if (
    isReminder && (!Number.isFinite(startsAt) || startsAt <= now.getTime() ||
      startsAt - now.getTime() > 3600_000)
  ) {
    // Expired or rescheduled reminders are consumed without bothering the user.
    return true;
  }

  const { data: tokens, error: tokenError } = await supabase
    .from("device_tokens")
    .select("apns_token")
    .eq("user_id", row.user_id);

  if (tokenError) throw new Error(tokenError.message);
  if (!tokens?.length) return true;

  const jwt = await getJwt();
  const sessionId = row.payload?.session_id;
  const url = sessionId ? `pickupucf://session/${sessionId}` : undefined;
  const openChat = row.payload?.open_chat === true ||
    row.type === "chat_message";
  const isSessionCancellation = row.type === "session_cancelled";
  const isCleanup = row.type === "session_finished";

  let anySuccess = false;
  for (const { apns_token } of tokens) {
    const endpoint = `${apnsBaseUrl()}/3/device/${apns_token}`;

    if ((isSessionCancellation || isCleanup) && sessionId) {
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
          ...(row.payload?.session_ends_at
            ? { session_ends_at: row.payload.session_ends_at }
            : {}),
        }),
      });

      if (isCleanup && backgroundResponse.ok) anySuccess = true;
      if (backgroundResponse.status === 410) {
        await supabase.from("device_tokens").delete().eq(
          "apns_token",
          apns_token,
        );
        continue;
      }
      if (!backgroundResponse.ok) {
        const failure = await reportAPNsFailure(
          backgroundResponse,
          onAPNsFailure,
        );
        if (isInvalidDeviceToken(failure)) {
          await supabase.from("device_tokens").delete().eq(
            "apns_token",
            apns_token,
          );
          continue;
        }
      }
    }

    if (isCleanup) continue;

    const res = await fetchImpl(
      endpoint,
      {
        method: "POST",
        headers: {
          authorization: `bearer ${jwt}`,
          "apns-topic": Deno.env.get("APNS_BUNDLE_ID")!,
          "apns-push-type": "alert",
          "apns-priority": "10",
          ...(isReminder
            ? { "apns-expiration": String(Math.floor(startsAt / 1000)) }
            : {}),
        },
        body: JSON.stringify({
          aps: {
            alert: { title: row.title, body: row.body },
            sound: "default",
          },
          ...(url ? { url } : {}),
          ...(sessionId ? { session_id: sessionId } : {}),
          ...(row.type ? { notification_type: row.type } : {}),
          ...(row.payload?.session_ends_at
            ? { session_ends_at: row.payload.session_ends_at }
            : {}),
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
    } else if (!res.ok) {
      const failure = await reportAPNsFailure(res, onAPNsFailure);
      if (isInvalidDeviceToken(failure)) {
        await supabase.from("device_tokens").delete().eq(
          "apns_token",
          apns_token,
        );
      }
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
  const providerJwt = deps.getJwt ?? getCachedApnsJwt;
  let requestJwt: Promise<string> | undefined;
  const requestDeps: HandlerDeps = {
    ...deps,
    getJwt: () => requestJwt ??= providerJwt(),
  };

  // Activity dismissal must not wait behind ordinary alert delivery.
  let liveActivitiesEnded: number;
  try {
    liveActivitiesEnded = await sendDueLiveActivities(supabase, requestDeps);
  } catch (liveActivityError) {
    const message = liveActivityError instanceof Error
      ? liveActivityError.message
      : "Failed to process Live Activities";
    return new Response(message, { status: 500 });
  }

  const { data: pending, error } = await supabase
    .from("notification_outbox")
    .select("id, user_id, title, body, type, payload")
    .is("sent_at", null)
    .order("created_at", { ascending: true })
    .limit(BATCH_SIZE);

  if (error) return new Response(error.message, { status: 500 });
  let sent = 0;
  for (const row of pending ?? []) {
    const ok = await sendToUserDevices(
      supabase,
      row as OutboxRow,
      requestDeps,
    );
    if (ok) {
      await supabase
        .from("notification_outbox")
        .update({ sent_at: (deps.now?.() ?? new Date()).toISOString() })
        .eq("id", row.id);
      sent++;
    }
  }

  return new Response(JSON.stringify({ sent, liveActivitiesEnded }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}

if (import.meta.main) {
  Deno.serve((req) => handler(req));
}
