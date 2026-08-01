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
- ✅ **App-launch biometric lock** (auto-lock on background; Settings toggle)
- ✅ **Motion & haptics system**: shared transitions, press feedback, animated balance, shimmer loading, staggered lists, semantic haptics
- ✅ CI: format + analyze + test

## Phase 2 — Security & polish
- ✅ **Address book**: save & label recipient DIDs; pick when sending
- ✅ **Amount UX**: max button, balance-aware validation, live remaining-after-send
- ✅ **Error surfaces**: friendly network/timeout/401 messages; offline banner
- ⬜ **Copy/share polish**: share DID sheet, richer QR (with label)
- ⬜ **Localization scaffolding** (i18n) and accessibility pass (semantics, contrast, dynamic type)

## Phase 3 — Protocol participation

- ✅ **Governance**: list proposals, cast votes, create proposals (`/governance/proposals`, `/governance/vote`)
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

- ✅ **Done node-side.** Real P2P transfer semantics now exist: the
  financial shard's transferable ledger is exposed at
  `GET /api/v1/financial/balance/:pubkey` and
  `POST /api/v1/financial/transfer`, authorized by the wallet's own
  Ed25519 signature. The recipient is credited by exactly what the sender
  is debited, and total supply is conserved. UBC stays soulbound on
  purpose — it meters what you may *do*; the financial ledger is what you
  may *pay*.
  - ✅ Wallet client layer wired (`KeyManager.financialTransferMessage`,
    `ApiClient.financialTransfer`, `WalletRepository.sendFinancial`),
    with cross-language test vectors pinned against the node.
  - 🔜 **Send/receive UX still targets the UBC path.** Receive must show
    the public key, not the DID — a `did:omnia:` is a one-way hash and
    cannot be paid to. Send needs an asset picker (UBC vs. transferable)
    and balance/nonce handling from the financial endpoints.
- A push-relay service + device-token registration for notifications
- Any new read endpoints the wallet surfaces (e.g. per-DID activity feed)

---

**Immediate next:** Phase 2 — app-launch biometric lock.
