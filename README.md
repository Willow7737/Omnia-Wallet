# Omnia Wallet

A self-custodial mobile wallet for the [Omnia Protocol](https://github.com/Willow7737/omnia-protocol), built with Flutter & Dart.

The wallet holds an Ed25519 keypair **on the device** (never a shared secret), derives an Omnia DID from the public key, and authenticates to an Omnia node with a challenge/signature login. v1 covers the core loop: **balance, send (spend) UBC, and transaction history.**

## How it works

```
┌──────────────┐  1. POST /api/v1/auth/challenge { public_key }         ┌────────────┐
│  Flutter app │ ───────────────────────────────────────────────────▶  │ Omnia node │
│              │  ◀─────────────────────────  { did, nonce, message }   │  REST API  │
│  Ed25519 key │                                                        │            │
│  (on device) │  2. sign("omnia-auth:" + nonce) with private key       │            │
│              │  3. POST /api/v1/auth/login { public_key, signature }   │            │
│              │  ◀─────────────────────────────  { did, token (JWT) }   │            │
│              │  4. Authorization: Bearer <JWT> for economics/* calls   │            │
└──────────────┘                                                        └────────────┘
```

- **DID derivation** (identical on both sides): `did:omnia:` + first 32 hex chars of `SHA-256(public_key_bytes)`. See `lib/crypto/key_manager.dart` and the node's `node/src/api/wallet_auth.rs`. A shared cross-repo test vector (`did:omnia:4bb06f8e4e3a7715d201d573d0aa4237` for a 32-byte `0x07` key) is asserted in both test suites to prevent drift.
- The private seed is stored in the platform keychain/keystore via `flutter_secure_storage` and only loaded to sign the login challenge. It never leaves the device.
- **UBC is soulbound**: a "send" *spends (burns)* tokens from your balance; the recipient DID is recorded for provenance but is **not** credited. The Send screen states this explicitly.

## Project layout

```
lib/
  core/        config, theme, router, formatting
  crypto/      key_manager (keygen/sign/DID), secure_store
  data/        api_client, models, auth_repository, wallet_repository
  state/       Riverpod providers
  features/    onboarding, home, send, receive, history, settings
test/          key_manager (crypto + DID vectors), models, widget/format
```

## Getting started

Prerequisites: Flutter (stable, ≥ 3.22) and a running Omnia node exposing the REST API.

```bash
flutter pub get

# Point the wallet at your node. On the Android emulator, 10.0.2.2 is the host.
flutter run --dart-define=OMNIA_NODE_URL=http://10.0.2.2:9090
```

The node URL is also editable at runtime from **Settings → Node endpoint** (persisted on device).

### Running a node locally

From the `omnia-protocol` repo:

```bash
OMNIA_JWT_SECRET=dev-secret cargo run -p omnia-node
```

The wallet's challenge/login endpoints (`/api/v1/auth/challenge`, `/api/v1/auth/login`) are public; all economics endpoints require the JWT the wallet obtains from them.

## Testing

```bash
flutter analyze
flutter test
```

Tests pin the SHA-256/DID derivation against canonical vectors so the wallet's identity always matches the node's.

## Scope

v1 is the core wallet loop. Governance/voting, events, validators, push notifications, multi-account, and hardware-key support are intentionally deferred.
