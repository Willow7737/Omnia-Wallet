# Releasing the Omnia Wallet to Google Play

This is the end-to-end runbook for shipping a signed Android App Bundle (AAB)
to the Google Play Console. It covers the one-time signing setup, the build,
and the Play Console steps (store listing, Data Safety, privacy policy).

> **Why an AAB and not an APK?** Google Play requires the Android App Bundle
> format. Play re-signs your app with the **app signing key** it holds; you
> only ever handle an **upload key**. Never commit either key.

---

## 0. Prerequisites

- Flutter (stable channel) + Android SDK, JDK 17.
- A Google Play Developer account (one-time $25). You said this is verified ✅.
- `flutter analyze` and `flutter test` green (CI enforces this).

---

## 1. One-time: create the upload keystore

Generate an RSA-2048 upload key valid for ~27 years:

```bash
keytool -genkey -v \
  -keystore ~/omnia-upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

You'll be prompted for a store password, a key password, and a distinguished
name. **Back this file up somewhere safe and private** — if you lose it you
can only recover via Google's key-reset process, and if it leaks an attacker
can publish updates to your app.

Then create `android/key.properties` (gitignored — see
`android/key.properties.example`):

```properties
storePassword=<store password>
keyPassword=<key password>
keyAlias=upload
storeFile=/absolute/path/to/omnia-upload-keystore.jks
```

`storeFile` may be absolute (recommended, keeps the key out of the repo) or
relative to the `android/` directory.

> The Gradle config (`android/app/build.gradle.kts`) loads `key.properties`
> automatically and signs `release` with it. If the file is absent it falls
> back to **debug** signing so the project still builds — but a debug-signed
> AAB is **rejected by Play**. Always confirm `key.properties` exists before a
> real release build.

---

## 2. Bump the version

Edit `pubspec.yaml`:

```yaml
version: 0.1.0+1
#        ^^^^^ versionName (shown to users)
#              ^ versionCode (must strictly increase every upload)
```

`versionCode` (the `+N`) **must be higher than any AAB previously uploaded**,
or Play rejects it. Bump it for every release.

---

## 3. Build the AAB

```bash
flutter clean
flutter pub get

# PRODUCTION build. `OMNIA_ENV=production` selects the production endpoints;
# omit it (or set anything else) for a testnet build.
flutter build appbundle --release \
  --dart-define=OMNIA_ENV=production \
  --dart-define=OMNIA_PROD_NODE_URL=https://<production-node-domain>
  # If you run a separate production Supabase project, also pass:
  #   --dart-define=OMNIA_PROD_SUPABASE_URL=https://<ref>.supabase.co
  #   --dart-define=OMNIA_PROD_SUPABASE_ANON_KEY=<anon key>
```

> **Environments.** The build defaults to **testnet**. A production listing
> must be built with `--dart-define=OMNIA_ENV=production`. Until you provide a
> dedicated production node domain, `OMNIA_PROD_NODE_URL` falls back to the
> current live network — replace it with a stable domain before public
> launch. See `lib/core/config.dart` for the full resolution order. The
> config also exposes `AppConfig.showNetworkBadge` / `AppConfig.networkLabel`
> so the UI can flag non-production builds.

Output: `build/app/outputs/bundle/release/app-release.aab`.

Sanity-check it's signed with your upload key (not debug):

```bash
jarsigner -verify -verbose -certs \
  build/app/outputs/bundle/release/app-release.aab | head
```

> **CI alternative:** push a tag `vX.Y.Z` (or run the *Release AAB* workflow
> manually). It builds and uploads the AAB as an artifact using the
> `ANDROID_KEYSTORE_BASE64` / `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEY_PASSWORD`
> / `ANDROID_KEY_ALIAS` repo secrets. See `.github/workflows/release.yml`.

---

## 4. Play Console — first-time app setup

1. **Create app** → name **Omnia Wallet**, language, app (not game), free.
2. **App signing**: accept **Play App Signing** (recommended). Play holds the
   app key; your upload key is what you just made.
3. **Store listing** — paste-ready copy, the graphic-asset checklist, and a
   content-rating cheat-sheet are in
   [`docs/play-store-listing.md`](./docs/play-store-listing.md):
   - Short description (≤80 chars) and full description.
   - App icon 512×512 PNG, feature graphic 1024×500.
   - At least 2 phone screenshots (grab from a device/emulator).
4. **Privacy policy URL**: host `PRIVACY.md` (e.g. GitHub Pages or on the
   Omnia web site) and paste the URL. **Required** — see §5.
5. **Content rating** questionnaire, **Target audience** (18+ recommended for
   a crypto/finance-adjacent utility), **Ads**: declare *no ads*.
6. **Data safety** form — see §6.

Then: upload the AAB under **Testing → Internal testing** first, add testers,
verify install/login/balance/send, and only then promote to **Production**.

---

## 5. Privacy policy

Play requires a publicly-hosted privacy policy URL. This repo ships one at
[`PRIVACY.md`](./PRIVACY.md) — host it and link it. It reflects the app's
actual data behaviour:

- **Self-custody keys** (Ed25519 seed/mnemonic) are generated on-device and
  stored in the Android Keystore via `flutter_secure_storage`. **They never
  leave the device** and are never transmitted to Omnia or anyone.
- The **node** sees pseudonymous protocol data (your DID, balance queries,
  signed transfers). UBC is a soulbound utility credit, not money.
- **Optional Supabase sign-in (Mode B)** and the social/news features collect
  an account identifier (e.g. email via OAuth), a username, an optional
  profile photo, and any content you post.

---

## 6. Data Safety form answers

Fill the Play Console **Data safety** section to match `PRIVACY.md`:

| Question | Answer |
|---|---|
| Does your app collect or share user data? | **Yes** (only if Mode B / social features are enabled; a pure self-custody user shares none) |
| Encrypted in transit? | **Yes** (HTTPS to the node and Supabase) |
| Can users request deletion? | **Yes** (account + posts via support; local wallet wiped from Settings) |
| **Personal info → Email address** | Collected (Mode B OAuth), for account management; not shared; optional |
| **Photos** (profile photo / news images) | Collected, user-initiated, for app functionality; not shared |
| **User-generated content** (posts/replies) | Collected, for app functionality |
| **Financial info** | *Not collected* — the on-device keys are never collected/transmitted; UBC balances are pseudonymous on-chain protocol state, not payment data |
| Precise location, contacts, health, etc. | **Not collected** |

> Keep this table and `PRIVACY.md` in sync whenever data behaviour changes.

---

## 7. Post-launch

- Increment `versionCode` every upload.
- Keep `targetSdk` current — Play enforces a minimum target API each year
  (this project inherits Flutter's `flutter.targetSdkVersion`; bump Flutter to
  stay compliant).
- Rotate the upload key only via Play Console if it is ever compromised.
