# Omnia Wallet — Privacy Policy

_Last updated: <!-- FILL IN: e.g. 22 July 2026 -->_
_Contact: <!-- FILL IN: e.g. privacy@omnia.example -->_

Omnia Wallet ("the app") is a self-custodial wallet for the Omnia Protocol.
This policy explains what data the app handles and what it does **not**.

## The short version

- **Your keys stay on your device.** The app generates an Ed25519 keypair
  (and its recovery phrase) on your phone and stores it in the operating
  system's secure hardware-backed store (Android Keystore). Your keys and
  recovery phrase are **never transmitted** to Omnia or anyone else.
- We do not sell your data. We do not use advertising or third-party
  analytics/tracking SDKs.
- Some features are optional and involve a server; those are described below.

## What stays only on your device

- Your wallet **private key / seed / recovery phrase** (secure storage).
- Your app settings, including the node URL and the app-lock preference.

These are accessible only to you and are removed if you wipe the wallet from
**Settings** or uninstall the app.

## Data sent to an Omnia node

To show your balance and submit transactions, the app talks to an Omnia
Protocol node (the default node, or one you configure in Settings) over
HTTPS. The node processes:

- your **DID** (a public identifier derived from your public key),
- balance and transaction-history queries,
- **signed spend authorizations** you create when sending UBC.

This is pseudonymous protocol data. **UBC is a soulbound utility credit, not
money**, and the app does not collect payment-card or bank information.

## Optional account sign-in and social features

The app offers an **optional** sign-in (via Google, GitHub, or email through
our authentication provider, Supabase) and optional social/news features.
If you choose to use them, we process:

- an **account identifier** such as your email address (for authentication),
- a **username** and an optional **profile photo**,
- any **posts, replies, or images** you choose to publish.

If you only use the self-custodial wallet and do not sign in or post, none of
this is collected.

## Device permissions

- **Internet** — to reach the Omnia node and (if used) the sign-in/social
  backend.
- **Camera** — only when you scan a recipient DID QR code. No images are
  stored or uploaded by the scanner.
- **Biometrics** — to unlock the app and confirm signing locally. Biometric
  data never leaves your device and is handled entirely by the OS.

## Security

- Traffic to servers is encrypted in transit (HTTPS/TLS).
- Private keys are held in the platform secure store and never leave the
  device.

## Your choices and deletion

- Wipe the on-device wallet any time from **Settings** (this is irreversible
  without your recovery phrase — back it up).
- To delete an optional account and any content you posted, contact us at the
  address above.

## Children

The app is not directed to children and is intended for users 18+.

## Changes

We may update this policy; the "Last updated" date reflects the current
version. Material changes will be surfaced in the app or its listing.
