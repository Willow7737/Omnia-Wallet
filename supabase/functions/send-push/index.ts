// send-push — deliver a notifications row to the account's handsets via FCM.
//
// Flow:
//   1. public.deliver_push (a trigger on public.notifications) calls this with
//      the service-role key and the new row.
//   2. This looks up every registered device for that user in
//      public.device_tokens.
//   3. It mints a Google OAuth access token from the FCM service account and
//      posts one message per device to FCM v1.
//   4. Tokens FCM reports as dead are deleted, so the table does not grow a
//      tail of uninstalled apps that every later send has to try.
//
// Deploy:
//   supabase functions deploy send-push --project-ref <your-ref>
//   supabase secrets set FCM_SERVICE_ACCOUNT="$(cat service-account.json)"
//   # SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected automatically.
//
// The service account JSON is a credential for your whole Firebase project.
// It lives in function secrets and never reaches a client.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token";

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

interface PushRequest {
  notification_id?: string;
  user_id?: string;
  title?: string;
  body?: string;
  link?: string | null;
  kind?: string;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function base64url(bytes: Uint8Array): string {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64urlJson(obj: unknown): string {
  return base64url(new TextEncoder().encode(JSON.stringify(obj)));
}

/// PEM (PKCS#8) to the raw DER bytes WebCrypto wants.
function pemToDer(pem: string): Uint8Array {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    // The JSON carries the key with literal \n escapes.
    .replace(/\\n/g, "")
    .replace(/\s+/g, "");
  const bin = atob(body);
  const der = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) der[i] = bin.charCodeAt(i);
  return der;
}

/// Exchange the service account for a short-lived access token, via the
/// JWT-bearer grant. This is the same handshake the Firebase Admin SDK does;
/// doing it by hand keeps this function to one dependency.
async function accessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64urlJson({ alg: "RS256", typ: "JWT" });
  const claims = base64urlJson({
    iss: account.client_email,
    scope: FCM_SCOPE,
    aud: GOOGLE_TOKEN_URL,
    iat: now,
    exp: now + 3600,
  });
  const signingInput = `${header}.${claims}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(account.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signingInput),
  );

  const response = await fetch(GOOGLE_TOKEN_URL, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${signingInput}.${base64url(new Uint8Array(signature))}`,
    }),
  });

  const payload = await response.json();
  if (!response.ok || !payload.access_token) {
    throw new Error(
      `google token exchange failed: ${response.status} ${
        JSON.stringify(payload)
      }`,
    );
  }
  return payload.access_token as string;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authHeader = req.headers.get("Authorization") ?? "";
  // Only the database trigger may call this. Without the check, anybody who
  // learned the URL could push arbitrary text to any user's lock screen.
  if (!serviceKey || authHeader !== `Bearer ${serviceKey}`) {
    return json({ error: "forbidden" }, 403);
  }

  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!raw) {
    // Nothing is configured yet. Not an error worth retrying — the in-app
    // notification is already written and is the part that must not depend
    // on Firebase being set up.
    return json({ skipped: "FCM_SERVICE_ACCOUNT is not set" }, 200);
  }

  let account: ServiceAccount;
  try {
    account = JSON.parse(raw);
  } catch {
    return json({ error: "FCM_SERVICE_ACCOUNT is not valid JSON" }, 500);
  }

  const payload: PushRequest = await req.json().catch(() => ({}));
  if (!payload.user_id) return json({ error: "user_id is required" }, 400);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    serviceKey,
  );

  const { data: devices, error: devicesError } = await supabase
    .from("device_tokens")
    .select("token")
    .eq("user_id", payload.user_id);

  if (devicesError) return json({ error: devicesError.message }, 500);
  if (!devices || devices.length === 0) return json({ sent: 0 });

  let token: string;
  try {
    token = await accessToken(account);
  } catch (e) {
    return json({ error: String(e) }, 502);
  }

  const endpoint =
    `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`;

  let sent = 0;
  const dead: string[] = [];

  await Promise.all(devices.map(async (device: { token: string }) => {
    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        message: {
          token: device.token,
          notification: {
            title: payload.title ?? "Omnia",
            body: payload.body ?? "",
          },
          // Everything the app needs to open the right screen on tap. FCM
          // requires data values to be strings.
          data: {
            kind: payload.kind ?? "news",
            link: payload.link ?? "",
            notification_id: payload.notification_id ?? "",
          },
          android: {
            priority: "high",
            notification: {
              channel_id: "omnia_replies",
              // Several replies to the same conversation collapse rather than
              // stacking up one per reply.
              tag: payload.link ?? "omnia",
            },
          },
          apns: {
            payload: { aps: { sound: "default" } },
          },
        },
      }),
    });

    if (response.ok) {
      sent++;
      return;
    }

    const error = await response.json().catch(() => ({}));
    const status = error?.error?.details?.[0]?.errorCode ??
      error?.error?.status;
    // The app was uninstalled, or the token was reissued. Either way this
    // address is permanently gone — keeping it means every future send pays
    // for a request that cannot succeed.
    if (
      response.status === 404 ||
      status === "UNREGISTERED" ||
      status === "INVALID_ARGUMENT"
    ) {
      dead.push(device.token);
    }
  }));

  if (dead.length > 0) {
    await supabase.from("device_tokens").delete().in("token", dead);
  }

  return json({ sent, pruned: dead.length });
});
