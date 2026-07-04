# Omnia Wallet — Roadmap

Status of the self-custodial Omnia mobile wallet and the planned feature sequence.
Legend: ✅ done · 🔜 next · ⬜ planned.

## Shipped (v1 — core loop)

- ✅ On-device Ed25519 keypair with BIP39 recovery phrase (create + import)
- ✅ Secure key storage (Keychain / Keystore); private key never leaves device
- ✅ Challenge/signature login → node JWT (`/auth/challenge`, `/auth/login`)
- ✅ DID derived from public key (`did:omnia:` + SHA-256), matching the node
- ✅ Balance / monthly quota / epoch (home)
- ✅ Send (spend) UBC with soulbound warning + biometric confirm
- ✅ Transaction history
- ✅ Receive: own DID as QR
- ✅ Settings: node endpoint, reveal recovery phrase, wipe wallet
- ✅ **Scan recipient DID via QR** (Send screen)
- ✅ CI: format + analyze + test

## Phase 2 — Security & polish

- 🔜 **App-launch lock**: biometric / device-credential gate when opening the app (auto-lock after background/timeout)
- ⬜ **Address book**: save & label frequently-used recipient DIDs
- ⬜ **Amount UX**: max button, balance-aware validation, confirmation of remaining balance
- ⬜ **Copy/share polish**: share DID sheet, richer QR (with label), pull-to-refresh everywhere
- ⬜ **Error surfaces**: friendlier network/timeout/401 messages; offline banner
- ⬜ **Localization scaffolding** (i18n) and accessibility pass (semantics, contrast, dynamic type)

## Phase 3 — Protocol participation

- ⬜ **Governance**: list proposals, view detail, cast votes (`/governance/proposals`, `/governance/vote`)
- ⬜ **Events**: submit and browse events (`/events`)
- ⬜ **Validators**: view registered validators, stake, jail status (`/validators`)
- ⬜ **Node/network status**: node info, peers, epoch countdown (`/node/info`, `/node/peers`)

## Phase 4 — Identity & accounts

- ⬜ **Multi-account**: derive multiple DIDs from one seed (BIP39 account index) with account switcher
- ⬜ **Watch-only / read-only** DIDs (paste a DID to monitor a balance)
- ⬜ **DID profile**: optional display name / avatar tied to the identity

## Phase 5 — Notifications & background

- ⬜ **Push notifications** for incoming activity / governance deadlines (requires a backend relay + device tokens)
- ⬜ **Background refresh** of balance/history
- ⬜ **Session auto-refresh** hardening (silent JWT renewal, retry/backoff on transient node errors)

## Phase 6 — Hardening & distribution

- ⬜ **Hardware-backed keys** (StrongBox / Secure Enclave) and optional passphrase-encrypted seed
- ⬜ **Screenshot protection** on sensitive screens (recovery phrase, send)
- ⬜ **Integration tests** against a live/dev node (end-to-end login → balance → send)
- ⬜ **Release pipeline**: signed Android (Play internal) + iOS (TestFlight) builds from CI
- ⬜ **Crash/analytics** (privacy-respecting, opt-in)

## Cross-cutting / protocol dependencies

Some items need node-side work in `omnia-protocol` before the wallet can consume them:

- Real incoming-transfer semantics (UBC is currently soulbound → "send" burns; a true P2P transfer model would change the send/receive UX)
- A push-relay service + device-token registration for notifications
- Any new read endpoints the wallet surfaces (e.g. per-DID activity feed)

---

**Immediate next:** Phase 2 — app-launch biometric lock.
