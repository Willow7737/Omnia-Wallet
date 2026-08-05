// Supabase Edge Function: mint-node-jwt
//
// Bridges a Supabase-authenticated user (Google / GitHub / email) to an Omnia
// node JWT, so the mobile wallet's "Sign in" path works for accounts that were
// created on the web (which have a server-side did:omnia:<8 hex> and no private
// key, and therefore can't use the wallet's challenge/signature login).
//
// Flow:
//   1. Client (wallet) sends `Authorization: Bearer <supabase access token>`.
//   2. This function verifies the token (getUser), looks up the caller's DID in
//      public.user_dids, and mints an RS256 node JWT { sub: did } signed with
//      OMNIA_JWT_SIGNING_KEY — matching the node's create_token(), so the node
//      accepts it.
//   3. Returns { did, token, expires_in }.
//
// Deploy:
//   supabase functions deploy mint-node-jwt --project-ref <your-ref>
//   supabase secrets set OMNIA_JWT_SIGNING_KEY=<PEM-encoded RSA private key> \
//     --project-ref <your-ref>
//   # Optional: set OMNIA_JWT_KEY_ID if the node uses key rotation.
//   # SUPABASE_URL and SUPABASE_ANON_KEY are injected automatically.
//
// The signing key never leaves the server — the wallet only ever sees the
// resulting short-lived node JWT.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const TOKEN_TTL_SECONDS = 86_400; // 24h, matches the node default.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function base64url(bytes: Uint8Array): string {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function base64urlJson(obj: unknown): string {
  return base64url(new TextEncoder().encode(JSON.stringify(obj)));
}

/** Import a PEM-encoded RSA private key into a CryptoKey for RS256 signing. */
async function importRsaSigningKey(
  pem: string,
): Promise<CryptoKey> {
  // Strip PEM armour and decode to raw bytes.
  const b64 = pem
    .replace(/-----BEGIN[^-]+-----/, "")
    .replace(/-----END[^-]+-----/, "")
    .replace(/\s/g, "");
  const raw = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));

  return crypto.subtle.importKey(
    "pkcs8",
    raw,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

/** Mint an RS256 JWT with { sub, iat, exp } claims. */
async function mintNodeJwt(
  did: string,
  signingKey: CryptoKey,
  kid: string | undefined,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header: Record<string, string> = { alg: "RS256", typ: "JWT" };
  if (kid) header.kid = kid;

  const headerB64 = base64urlJson(header);
  const claimsB64 = base64urlJson({
    sub: did,
    iat: now,
    exp: now + TOKEN_TTL_SECONDS,
  });
  const signingInput = `${headerB64}.${claimsB64}`;

  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    signingKey,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${base64url(new Uint8Array(sig))}`;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS")
    return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST")
    return json({ error: "method not allowed" }, 405);

  const signingKeyPem = Deno.env.get("OMNIA_JWT_SIGNING_KEY");
  if (!signingKeyPem) {
    return json(
      { error: "OMNIA_JWT_SIGNING_KEY not configured" },
      500,
    );
  }

  const kid = Deno.env.get("OMNIA_JWT_KEY_ID")?.trim() || undefined;

  let signingKey: CryptoKey;
  try {
    signingKey = await importRsaSigningKey(signingKeyPem);
  } catch (e) {
    return json(
      { error: `failed to parse OMNIA_JWT_SIGNING_KEY: ${e}` },
      500,
    );
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return json({ error: "missing bearer token" }, 401);
  }

  // A client scoped to the caller's token so getUser() verifies it and RLS
  // applies when reading user_dids.
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const {
    data: { user },
    error: userErr,
  } = await supabase.auth.getUser();
  if (userErr || !user) return json({ error: "invalid session" }, 401);

  const { data: didRow, error: didErr } = await supabase
    .from("user_dids")
    .select("did")
    .eq("user_id", user.id)
    .single();

  if (didErr || !didRow?.did) {
    return json({ error: "no DID for this user" }, 404);
  }

  const did = didRow.did as string;
  const token = await mintNodeJwt(did, signingKey, kid);
  return json({ did, token, expires_in: TOKEN_TTL_SECONDS });
});
