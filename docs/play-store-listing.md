# Play Store listing — copy & submission cheat-sheet

Paste-ready text and answers for the Google Play Console. Tune to taste;
everything here matches the app's actual behaviour (keep it honest — Play
reviews against the app and against `PRIVACY.md` / the Data Safety form).

---

## ⚠️ Read first: the org-account rejection (July 2026)

The first submission was **rejected** under **Play Console Requirements** —
not for content or code, but because Play routes apps that look like
*cryptocurrency software wallets* to organization-only distribution.

The listing itself invited that classification. It declared the **Finance**
category, a **crypto** tag, and described sending UBC as a "payment" you
"get paid" — none of which is accurate for UBC. The app's own transaction
screen states the truth: a transfer **burns** UBC from the sender and the
**recipient is not credited**. That is not a payment, and UBC cannot be
bought, sold, traded, or priced.

The declarations below have been corrected to match what the app actually
does. See [`play-appeal.md`](./play-appeal.md) for the appeal, and the
"Organization account" section at the end of this file for the durable fix.

---

## App details

- **App name:** `Omnia Wallet` — ⚠️ **decision pending.** The word "Wallet"
  plus self-custody keys is the single strongest signal pushing reviewers to
  the crypto-wallet bucket. Lower-risk alternatives that keep the brand:
  `Omnia`, `Omnia Protocol`, `Omnia — Identity & Compute`. The Android
  `applicationId` (`com.omnia.wallet`) is permanent and does **not** need to
  change; only `android:label` and the Play listing title do.
- **Default language:** English (United States)
- **App or game:** App
- **Free or paid:** Free
- **Category:** **Tools** (primary). Alternative: Productivity.
  **Do not select Finance** — Omnia offers no financial product or service:
  no money, no purchases, no trading, no exchange, no fiat rails.
- **Tags:** identity, self-custody, decentralized, developer tools
  (**do not** use `crypto`, `wallet`, `finance`, or `payments` tags)
- **Contact email:** _fill in_ · **Website:** _fill in_
- **Privacy policy:** `https://willow7737.github.io/omnia-web/wallet/privacy/`
- **Account deletion:** `https://willow7737.github.io/omnia-web/wallet/delete-account/`

### Financial features declaration (App content)

Answer **"My app doesn't provide any financial features."** This is accurate:
UBC is a soulbound compute quota that cannot be purchased, transferred for
value, or redeemed. The app facilitates no payment, investment, lending,
exchange, or money transmission.

---

## Short description (≤ 80 chars)

> Your Omnia identity and compute quota — keys stay on your device.

(63/80. Alternatives:)
- `Self-custody identity for the Omnia Protocol. Keys never leave your phone.` (74)
- `Omnia Protocol client — your DID, your compute quota, your control.` (67)

> Avoid "wallet", "payments", "crypto" and "assets" in the short description
> — this is the text reviewers and classifiers read first.

---

## Full description (≤ 4000 chars)

> **Omnia is the self-custody client for the Omnia Protocol** — an
> open-source, public-domain coordination network. It holds your
> decentralized identity and shows your Universal Basic Compute (UBC)
> allowance, the quota that lets you use the network.
>
> **UBC is not money.** It is a soulbound compute credit, granted monthly to
> every identity. It cannot be bought, sold, traded, exchanged, or converted
> to any currency, and it has no monetary value. Omnia offers no financial
> product or service of any kind.
>
> **An identity you actually own**
> A secure Ed25519 identity (your `did:omnia:` DID) is created on first
> launch and stored in your phone's hardware-backed keystore. Back it up with
> a standard recovery phrase; restore it on any device. Omnia never sees your
> keys.
>
> **Verifiable, transparent records**
> Allocate UBC to another identity and watch the record move through its
> finality lifecycle — from fast preconfirmation to canonical settlement — so
> you always know exactly how settled it is. Allocating UBC *spends* it from
> your quota; the recipient identity is recorded for provenance and is not
> credited a balance.
>
> **Built for the Omnia Protocol**
> - Check your compute quota, current epoch, and usage at a glance.
> - Allocate UBC with a biometric confirmation before anything is signed.
> - Scan an identity's DID by QR, or share your own.
> - Review your full, verifiable activity history.
> - Take part in governance and follow protocol news.
>
> **Private by design**
> No ads. No third-party tracking. Biometric app lock. Private keys never
> leave your device. Read our privacy policy for exactly what an optional
> sign-in and the social features involve.

> **Wording rules for this listing.** Never describe UBC as a payment,
> currency, asset, token-you-can-hold-value-in, or something to "get paid"
> in — all of those are factually wrong (transfers burn UBC) and each one
> re-triggers the financial-services classifier. Prefer: *compute quota*,
> *allowance*, *allocate*, *identity*, *record*.

(Keep under 4000 chars — the above is ~1.1k.)

---

## "What's new" (release notes, first release)

> First public release of Omnia Wallet: self-custodial keys, send/receive
> UBC, QR scanning, transaction history with finality status, biometric
> lock, governance, and news.

---

## Graphic assets checklist

> Brand-matched source art (feature graphic + 512 icon) is in
> [`assets/store/`](../assets/store/) with SVG→PNG export instructions.

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
- **User-generated content moderation:** **Yes — implemented.** The app ships
  the moderation surface Play expects for interactive UGC:
  - **Report:** every reply has a “···” → **Report** action that files a
    categorised report (spam, harassment, hate speech, sexual, violence,
    other) into the `content_reports` table for the moderation team; reporters
    see “reviewed within 24 hours”.
  - **Block:** users can block an author from the same menu; blocked authors’
    posts and replies are hidden from that user’s feed (managed under
    **Settings → Safety**).
  - **Community guidelines:** published in-app at **Settings → Safety**,
    stating that violating content is removed and repeat offenders lose access.
  Describe this flow in the questionnaire; no “plan for it later” caveat is
  needed.

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

---

## Organization account (the durable fix)

Since 31 Aug 2024, Play requires an **organization developer account** for
apps providing financial services — a bucket that explicitly names
"cryptocurrency software wallets." Even after the corrections above, an app
that holds self-custody keys for a distributed ledger can still be routed
into that bucket by a reviewer. An organization account removes the question
permanently.

**What it needs**

| Requirement | Notes |
|---|---|
| A registered legal entity | e.g. an incorporated company |
| **D-U-N-S number** | Free from Dun & Bradstreet. Allow **~30 days**; expedited options exist. This is the long pole — start it first. |
| Organization Play Console account | $25 one-time registration, same as individual |
| Verification | Legal name, address, and contact must match the D-U-N-S record exactly |

**Migrating the app.** Because this submission was rejected and never
published, the simplest route is to create the app fresh under the
organization account using the same `applicationId` and the same upload
keystore. (Play also supports transferring a *published* app between
accounts, but that is unnecessary here.)

**Recommended sequence**

1. **Today:** start the D-U-N-S application — it gates everything else.
2. **Today:** apply the declaration corrections above and submit the appeal
   (see [`play-appeal.md`](./play-appeal.md)). If it succeeds you ship sooner.
3. **On D-U-N-S issue:** register the organization account and publish there
   regardless — it is the position you want long-term.
