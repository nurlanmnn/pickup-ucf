import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "https://esm.sh/jose@5.9.6";

export const BATCH_SIZE = 50;

export interface OutboxRow {
  id: string;
  user_id: string;
  title: string;
  body: string;
  payload?: { session_id?: string };
}

export interface HandlerDeps {
  supabase?: SupabaseClient;
  fetchImpl?: typeof fetch;
  getJwt?: () => Promise<string>;
}

export function apnsBaseUrl(): string {
  return Deno.env.get("APNS_ENV") === "sandbox"
    ? "https://api.sandbox.push.apple.com"
    : "https://api.push.apple.com";
}

export function isAuthorized(req: Request, cronSecret: string | undefined): boolean {
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

  let anySuccess = false;
  for (const { apns_token } of tokens) {
    const res = await fetchImpl(
      `${apnsBaseUrl()}/3/device/${apns_token}`,
      {
        method: "POST",
        headers: {
          authorization: `bearer ${jwt}`,
          "apns-topic": Deno.env.get("APNS_BUNDLE_ID")!,
          "apns-push-type": "alert",
          "apns-priority": "10",
        },
        body: JSON.stringify({
          aps: { alert: { title: row.title, body: row.body }, sound: "default" },
          ...(url ? { url } : {}),
        }),
      },
    );

    if (res.ok) anySuccess = true;
    if (res.status === 410) {
      await supabase.from("device_tokens").delete().eq("apns_token", apns_token);
    }
  }

  return anySuccess || !tokens.length;
}

export async function handler(req: Request, deps: HandlerDeps = {}): Promise<Response> {
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
    .select("id, user_id, title, body, payload")
    .is("sent_at", null)
    .order("created_at", { ascending: true })
    .limit(BATCH_SIZE);

  if (error) return new Response(error.message, { status: 500 });
  if (!pending?.length) {
    return new Response(JSON.stringify({ sent: 0 }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  let sent = 0;
  for (const row of pending) {
    const ok = await sendToUserDevices(supabase, row as OutboxRow, deps);
    if (ok) {
      await supabase
        .from("notification_outbox")
        .update({ sent_at: new Date().toISOString() })
        .eq("id", row.id);
      sent++;
    }
  }

  return new Response(JSON.stringify({ sent }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}

if (import.meta.main) {
  Deno.serve((req) => handler(req));
}
