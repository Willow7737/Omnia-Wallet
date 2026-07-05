# Dual-mode authentication

The wallet supports two identity paths so it works for both crypto-native users
and the users who already signed up on the web (Supabase).

## Mode A — Self-custodial (implemented)
On-device Ed25519 key → `did:omnia:` + `sha256(pubkey)[..32]` → the node's
challenge/signature login (`/api/v1/auth/challenge` + `/auth/login`). The
private key never leaves the device.

## Mode B — Supabase account (server-assisted)
For accounts created on the web via **Google / GitHub / email**. These have a
server-side DID (`did:omnia:` + 8 hex, from the `on_auth_user_created` trigger
in `omnia-protocol-interface/supabase/schema.sql`) and **no private key**, so
they can't use challenge/signature login. Instead:

1. The wallet signs the user in with `supabase_flutter`.
2. It calls the **`mint-node-jwt` edge function** (this repo,
   `supabase/functions/mint-node-jwt/`) with the Supabase access token.
3. The function verifies the token, reads the user's DID from `user_dids`, and
   mints an HS256 node JWT (`sub = did`) with `OMNIA_JWT_SECRET`.
4. The wallet uses that JWT for `economics/*`, `governance/*`, etc.

`OMNIA_JWT_SECRET` stays server-side; the wallet only ever holds the resulting
short-lived node JWT.

## Deploying the edge function
The omnia Supabase project (`iyajzmgnykgkivabxiuw`) lives in a different org, so
deploy it from your machine:

```bash
supabase functions deploy mint-node-jwt --project-ref iyajzmgnykgkivabxiuw
supabase secrets set OMNIA_JWT_SECRET=<the same secret the node runs with> \
  --project-ref iyajzmgnykgkivabxiuw
```

## What the wallet client still needs (to finish Mode B)
- `SUPABASE_URL` = `https://iyajzmgnykgkivabxiuw.supabase.co`
- `SUPABASE_ANON_KEY` (public; safe to ship / pass via `--dart-define`)
- The deployed `mint-node-jwt` function URL

Wire-up (next step): add `supabase_flutter`, an onboarding "Sign in" path
(Google / GitHub / email), fetch the DID + node JWT via the function, and route
the existing repositories through the resulting session. OAuth on mobile also
needs a deep-link redirect scheme configured in `AndroidManifest.xml` /
`Info.plist`.
