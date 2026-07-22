# Play Store listing — copy & submission cheat-sheet

Paste-ready text and answers for the Google Play Console. Tune to taste;
everything here matches the app's actual behaviour (keep it honest — Play
reviews against the app and against `PRIVACY.md` / the Data Safety form).

---

## App details

- **App name:** `Omnia Wallet` (30 char max — 12/30 used)
- **Default language:** English (United States)
- **App or game:** App
- **Free or paid:** Free
- **Category:** **Finance** (primary). Alternative: Tools.
- **Tags:** wallet, crypto, self-custody, identity
- **Contact email:** _fill in_ · **Website:** _fill in_ · **Privacy policy:** _hosted PRIVACY.md URL_

---

## Short description (≤ 80 chars)

> Self-custodial Omnia wallet — your keys, your UBC. Send, track, and verify.

(63/80. Alternatives:)
- `Self-custody wallet for the Omnia Protocol. Your keys never leave the phone.` (76)
- `Omnia Protocol wallet — hold UBC, send instantly, stay in control.` (65)

---

## Full description (≤ 4000 chars)

> **Omnia Wallet is a self-custodial wallet for the Omnia Protocol.** Your
> keys are generated on your device and never leave it — you're always in
> control of your UBC.
>
> **Your keys, your control**
> A secure Ed25519 identity is created on first launch and stored in your
> phone's hardware-backed keystore. Back it up with a standard recovery
> phrase; restore it on any device. Omnia never sees your keys.
>
> **Fast, verifiable transactions**
> Send UBC in seconds and watch each transaction move through its finality
> lifecycle — from fast preconfirmation to canonical settlement — so you
> always know exactly how final a payment is.
>
> **Built for the Omnia Protocol**
> - Check your balance, monthly quota, and current epoch at a glance.
> - Send UBC with a biometric confirmation before anything is signed.
> - Scan a recipient's DID by QR, or share your own to get paid.
> - Review your full, verifiable transaction history.
> - Take part in governance and follow protocol news.
>
> **Private by design**
> No ads. No third-party tracking. Biometric app lock. Private keys never
> leave your device. Read our privacy policy for exactly what an optional
> sign-in and the social features involve.
>
> UBC is a soulbound utility credit of the Omnia Protocol — not a
> speculative asset or a payment instrument.

(Keep under 4000 chars — the above is ~1.1k.)

---

## "What's new" (release notes, first release)

> First public release of Omnia Wallet: self-custodial keys, send/receive
> UBC, QR scanning, transaction history with finality status, biometric
> lock, governance, and news.

---

## Graphic assets checklist

| Asset | Spec | Notes |
|---|---|---|
| App icon | 512×512 PNG, 32-bit, ≤1 MB | Your launcher mark on a solid/again-safe background. |
| Feature graphic | 1024×500 PNG/JPG | Shown atop the listing. Wordmark + tagline on the brand palette. |
| Phone screenshots | 2–8, PNG/JPG, 16:9 or 9:16, each side 1080–3840 px | Capture Home (balance), Send, History (finality states), Receive (QR). |
| (optional) 7" / 10" tablet shots | same rules | Only if you market tablet support. |

Grab screenshots from a device/emulator: `flutter run --release`, then the
device screenshot control. Frame them with a short caption band if you want
polish, but raw screenshots are accepted.

---

## Content rating (IARC questionnaire) cheat-sheet

Category: **Utility / Productivity / Communication** (a wallet with social
features). Answer truthfully; typical answers for this app:

- Violence / scary / sexual / profanity / drugs / gambling: **No** to all.
- **Does the app let users interact or exchange content?** **Yes** — the
  app has optional social/news features (users can post and reply).
- **Can users share their location with others?** **No.**
- **Digital purchases / real-currency gambling?** **No.** (UBC is a soulbound
  utility credit, not purchasable currency or a gambling mechanic.)
- **User-generated content moderation:** be ready to describe that posts can
  be reported/removed. (If you don't yet have moderation tooling, plan for it
  — Play expects a way to handle objectionable UGC.)

Expected result: rated for a general/teen audience. **Target audience:**
select **18+** given the finance/crypto context.

---

## Ads & pricing

- **Contains ads:** No.
- **In-app purchases:** No.
- **Free.**

---

## Submission order (recommended)

1. Internal testing track first — upload the AAB, add your own account as a
   tester, install, and verify create-wallet → balance → send → history.
2. Complete: Store listing, Data Safety (see RELEASE.md §6), Content rating,
   Target audience, Privacy policy URL, App access (provide test
   credentials/notes if any screen is gated).
3. Promote the same build to **Production** (or Closed testing first).

> **Pre-production reminder** (from RELEASE.md): the app currently defaults to
> a testnet node and testnet Supabase project. For a public production
> listing, build with `--dart-define=OMNIA_NODE_URL=...` (and Supabase vars)
> pointing at production endpoints.
