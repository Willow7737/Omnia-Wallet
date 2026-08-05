# Dual-mode authentication

The wallet supports two identity paths so it works for both crypto-native users
and the users who already signed up on the web (Supabase).

## Mode A — Self-custodial (implemented)
On-device Ed25519 key -> `did:omnia:` + `sha256(pubkey)[..32]` -> the node's
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
   mints an RS256 node JWT (`sub = did`) signed with `OMNIA_JWT_SIGNING_KEY`
   — the same RSA private key the node uses to issue its own tokens.
4. The wallet uses that JWT for `economics/*`, `governance/*`, etc.

`OMNIA_JWT_SIGNING_KEY` stays server-side; the wallet only ever holds the
resulting short-lived node JWT.

## Deploying the edge function
The omnia Supabase project (`iyajzmgnykgkivabxiuw`) lives in a different org, so
deploy it from your machine:

```bash
supabase functions deploy mint-node-jwt --project-ref iyajzmgnykgkivabxiuw
supabase secrets set OMNIA_JWT_SIGNING_KEY="$(cat /path/to/node-rsa-private.pem)" \
  --project-ref iyajzmgnykgkivabxiuw
# Optional — only if the node has OMNIA_JWT_KEY_ID set:
supabase secrets set OMNIA_JWT_KEY_ID=<key-id> \
  --project-ref iyajzmgnykgkivabxiuw
```

> **Migration note (RS256):** Previous versions of this function used
> `OMNIA_JWT_SECRET` to sign HS256 tokens. The node now requires RS256 by
> default. Update the Supabase secret from the old HMAC secret to the RSA
> private key PEM that the node uses (`OMNIA_JWT_SIGNING_KEY`). Remove the
> old `OMNIA_JWT_SECRET` secret from the Supabase project.

## Wallet client wire-up (implemented)
- `supabase_flutter` is initialised at app start (`SupabaseFlutterGateway.init`)
  with `AppConfig.supabaseUrl` / `AppConfig.supabaseAnonKey` — both have
  working defaults and can be overridden via
  `--dart-define=OMNIA_SUPABASE_URL=... --dart-define=OMNIA_SUPABASE_ANON_KEY=...`
  (the anon key is public by design).
- Onboarding has a third card, **"Sign in with your Omnia account"** ->
  `/signin` with Google, GitHub, and email + password.
- After Supabase authenticates, `AuthRepository.completeSupabaseSignIn()`
  calls the edge function via `MintJwtClient`, stores the DID + auth mode, and
  every subsequent `ensureSession()` transparently re-mints the node JWT.
- OAuth returns to the app via the deep link `io.omnia.wallet://login-callback/`
  (intent filter in `AndroidManifest.xml`, `CFBundleURLTypes` in `Info.plist`).
- Mode-aware UI: Settings hides "Reveal recovery phrase" and offers
  **Sign out** instead of wallet removal; Profile shows the account email.

## Remaining server-side checklist
1. **`OMNIA_JWT_SIGNING_KEY`** must be set on the Supabase project (Dashboard ->
   Edge Functions -> Secrets) to the **same RSA private key PEM the node runs
   with** (`OMNIA_JWT_SIGNING_KEY`). Until then the edge function returns 500.
   If the node uses `OMNIA_JWT_KEY_ID`, set that secret too.
2. Remove the old `OMNIA_JWT_SECRET` secret from the Supabase project — it is
   no longer used and keeping it around is confusing.
3. Add `io.omnia.wallet://login-callback/` to Supabase -> Auth ->
   URL Configuration -> **Redirect URLs** (needed for Google/GitHub sign-in).
