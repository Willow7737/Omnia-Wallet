# Omnia Wallet

> **Self-custodial mobile wallet for the Omnia Protocol**

[![Flutter](https://img.shields.io/badge/Flutter-3.22+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.4+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Omnia Wallet** is a secure, self-custodial mobile application built with Flutter & Dart that brings Universal Basic Compute (UBC) to your pocket. Your keys, your identity, your control.

---

## 📱 App Preview

### Onboarding Experience

<div align="center">

| Stay in the Loop | Meet Your Wallet | Your Keys, Your DID | Send. Vote. Take Part |
|-----------------|------------------|---------------------|----------------------|
| ![Stay in the loop](assets/screenshots/Screenshot_20260709-191548.jpg) | ![Meet your Omnia wallet](assets/screenshots/Screenshot_20260709-191542.jpg) | ![Your keys, your DID](assets/screenshots/Screenshot_20260709-191544.jpg) | ![Send Vote Take Part](assets/screenshots/Screenshot_20260709-191546.jpg) |

</div>

### Core Features

<div align="center">

| Welcome Screen | Settings | Profile | Transaction History |
|----------------|----------|---------|---------------------|
| ![Welcome Screen](assets/screenshots/Screenshot_20260709-191552.jpg) | ![Settings](assets/screenshots/Screenshot_20260709-191525.jpg) | ![Profile](assets/screenshots/Screenshot_20260709-191507.jpg) | ![History](assets/screenshots/Screenshot_20260709-191446.jpg) |

</div>

### Additional Features

<div align="center">

| Recovery Phrase | News Feed | Your DID QR | Send UBC | Home Balance |
|----------------|-----------|-------------|----------|--------------|
| ![Recovery Phrase](assets/screenshots/Screenshot_20260709-191602.jpg) | ![News Feed](assets/screenshots/Screenshot_20260709-192112.jpg) | ![Your DID QR](assets/screenshots/Screenshot_20260709-191442.jpg) | ![Send UBC](assets/screenshots/Screenshot_20260709-191438.jpg) | ![Home Balance](assets/screenshots/Screenshot_20260709-191430.jpg) |

</div>

---

## 🔐 Security First

Omnia Wallet puts **your security first**:

- ✅ **Self-custodial**: Your Ed25519 private key is generated and stored **on-device only**
- ✅ **Never leaves device**: Private key never transmitted or shared
- ✅ **Secure storage**: Uses platform keychain/keystore via `flutter_secure_storage`
- ✅ **Biometric protection**: Optional biometric authentication before signing
- ✅ **BIP39 recovery**: 12-word mnemonic phrase for wallet backup (shown above)
- ✅ **Deterministic DID**: `did:omnia:` + SHA-256(public_key) - consistent across devices

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Omnia Wallet                              │
├─────────────────────────────────────────────────────────────┤
│  lib/                                                           │
│  ├── core/           Config, theme, router, formatting        │
│  ├── crypto/         Ed25519 keygen/sign, DID derivation        │
│  │   └── key_manager.dart    # Key generation & storage      │
│  ├── data/           API client, models, repositories         │
│  │   ├── api_client.dart     # REST API communication        │
│  │   ├── auth_repository.dart # Authentication flow           │
│  │   └── wallet_repository.dart # Wallet operations          │
│  ├── state/          Riverpod providers (state management)   │
│  └── features/       UI feature modules                       │
│      ├── onboarding/  # Wallet creation & recovery            │
│      ├── home/        # Balance & overview                     │
│      ├── send/        # Send UBC                               │
│      ├── receive/     # Receive & QR display                      │
│      ├── history/     # Transaction history                   │
│      └── settings/    # Configuration & preferences            │
└─────────────────────────────────────────────────────────────┘

Challenge/Signature Login Flow:

┌──────────────┐  1. POST /api/v1/auth/challenge { public_key }  ┌────────────┐
│  Flutter app │ ─────────────────────────────────────────────────▶│ Omnia node │
│  (on device) │ ◀────────────── { did, nonce, message }            │  REST API  │
│              │                                                   │            │
│  Ed25519 key │  2. sign("omnia-auth:" + nonce) with private key    │            │
│              │ ─────────────────────────────────────────────────▶│            │
│              │  3. POST /api/v1/auth/login { public_key, signature }│            │
│              │ ◀────────────── { did, token (JWT) }               │            │
│              │  4. Authorization: Bearer <JWT> for all calls     │            │
└──────────────┘                                                   └────────────┘
```

---

## 🚀 Features

### ✅ Core v1 (Shipped)

- **On-device Ed25519 keypair** with BIP39 recovery phrase (create + import)
- **Secure key storage** using platform keychain/keystore
- **Challenge/signature login** → node JWT authentication
- **DID derivation** from public key (`did:omnia:` + SHA-256)
- **Balance display** with monthly quota and epoch information
- **Send UBC** with soulbound warning and biometric confirmation
- **Transaction history** with detailed activity tracking
- **Receive screen** with own DID as QR code
- **Settings**: Node endpoint configuration, recovery phrase reveal, wallet wipe
- **QR scanning** for recipient DIDs on Send screen
- **App-launch biometric lock** with auto-lock on background
- **Motion & haptics system**: Shared transitions, press feedback, animated balance
- **News feed** with protocol updates and governance information

### 🔜 Upcoming Features

- **Address book**: Save and label recipient DIDs
- **Governance participation**: List proposals, cast votes, create proposals
- **Multi-account support**: Multiple DIDs from one seed
- **Push notifications** for incoming activity
- **Hardware-backed keys** (StrongBox / Secure Enclave)
- **Localization & accessibility** support

---

## 📦 Tech Stack

| Category | Technology | Purpose |
|----------|------------|---------|
| **Framework** | Flutter 3.22+ | Cross-platform mobile development |
| **Language** | Dart 3.4+ | Primary development language |
| **State Management** | Riverpod 2.5+ | Reactive state management |
| **Cryptography** | ed25519_edwards | Ed25519 key generation & signing |
| **BIP39** | bip39 | Mnemonic phrase backup/recovery |
| **Hashing** | crypto | SHA-256 for DID derivation |
| **Secure Storage** | flutter_secure_storage | Platform keychain/keystore |
| **Biometrics** | local_auth | Biometric authentication |
| **Networking** | dio | HTTP client for REST API |
| **QR Code** | qr_flutter, mobile_scanner | QR generation & scanning |
| **Navigation** | go_router | Declarative routing |
| **Authentication** | supabase_flutter | Mode B sign-in support |
| **UI** | flutter_svg | SVG vector art rendering |
| **Images** | image_picker, path_provider | Image handling |
| **Internationalization** | intl | Formatting & localization |

---

## 🛠️ Getting Started

### Prerequisites

- Flutter (stable, ≥ 3.22)
- Dart SDK (≥ 3.4.0)
- A running Omnia node exposing the REST API

### Installation

```bash
# Clone the repository
git clone https://github.com/Willow7737/Omnia-Wallet.git
cd Omnia-Wallet

# Install dependencies
flutter pub get

# Run on Android emulator (10.0.2.2 is host)
flutter run --dart-define=OMNIA_NODE_URL=http://10.0.2.2:9090

# Run on iOS simulator
flutter run --dart-define=OMNIA_NODE_URL=http://localhost:9090
```

### Running a Node Locally

From the `omnia-protocol` repository:

```bash
OMNIA_JWT_SECRET=dev-secret cargo run -p omnia-node
```

The wallet authenticates via challenge/signature flow at:
- `/api/v1/auth/challenge` - Get authentication challenge
- `/api/v1/auth/login` - Submit signed challenge for JWT

All economics endpoints require the JWT obtained from the login flow.

---

## 📁 Project Structure

```
omnia-wallet/
├── lib/
│   ├── core/              # App configuration, theme, router
│   │   ├── config.dart    # Environment configuration
│   │   ├── theme.dart     # App theming & styling
│   │   └── router.dart    # Navigation routes
│   │
│   ├── crypto/            # Cryptographic operations
│   │   ├── key_manager.dart # Ed25519 key generation, signing, DID
│   │   └── secure_store.dart # Secure storage wrapper
│   │
│   ├── data/              # Data layer
│   │   ├── models/        # Data models (DID, Transaction, etc.)
│   │   ├── api_client.dart # REST API client
│   │   ├── auth_repository.dart # Authentication logic
│   │   └── wallet_repository.dart # Wallet operations
│   │
│   ├── state/             # State management (Riverpod)
│   │   ├── auth_provider.dart # Authentication state
│   │   ├── wallet_provider.dart # Wallet state
│   │   └── settings_provider.dart # Settings state
│   │
│   └── features/          # UI feature modules
│       ├── onboarding/    # Wallet creation & recovery
│       ├── home/          # Main wallet screen
│       ├── send/          # Send UBC flow
│       ├── receive/       # Receive & QR display
│       ├── history/       # Transaction history
│       └── settings/      # App settings
│
├── android/               # Android platform code
├── ios/                   # iOS platform code
├── assets/                # Static assets
│   ├── logo/              # App logos
│   ├── illustrations/     # App illustrations
│   ├── brand_icons/        # Brand icons
│   ├── onboarding/        # Onboarding images
│   └── screenshots/       # App screenshots
│
├── test/                  # Tests
│   ├── crypto/            # Cryptographic tests
│   └── widgets/           # Widget tests
│
├── pubspec.yaml           # Flutter dependencies
├── README.md              # This file
├── ROADMAP.md             # Development roadmap
└── CREDITS.md             # Credits & acknowledgments
```

---

## 🧪 Testing

```bash
# Run static analysis
flutter analyze

# Run all tests
flutter test

# Run specific test file
flutter test test/crypto/key_manager_test.dart
```

Tests include:
- SHA-256/DID derivation against canonical vectors
- Ed25519 key generation and signing
- Wallet state management
- Widget rendering and interactions

---

## 📊 UBC Soulbound Model

> ⚠️ **Important**: UBC is currently **soulbound**

When you "send" UBC in the current implementation:
- Tokens are **burned** from your balance (not transferred)
- The recipient DID is recorded for provenance
- The recipient does **NOT** receive the tokens
- This is a **spend** operation, not a transfer

The Send screen explicitly states this behavior with a prominent warning. Future protocol updates may introduce true P2P transfer semantics.

---

## 🔗 API Endpoints

### Authentication
- `POST /api/v1/auth/challenge` - Request authentication challenge
- `POST /api/v1/auth/login` - Submit signed challenge, receive JWT

### Economics
- `GET /api/v1/economics/balance` - Get current balance
- `GET /api/v1/economics/history` - Get transaction history
- `POST /api/v1/economics/send` - Send/spend UBC

### Governance (Phase 3)
- `GET /api/v1/governance/proposals` - List governance proposals
- `POST /api/v1/governance/vote` - Cast a vote
- `POST /api/v1/governance/proposals` - Create a proposal

---

## 🎯 DID Format

Omnia DIDs follow this format:

```
did:omnia:<first_32_hex_chars_of_SHA256(public_key_bytes)>
```

**Example**: `did:omnia:71a9c0e0`

This format is:
- Deterministic: Same public key always produces the same DID
- Cross-platform: Consistent between wallet and node
- Verifiable: Both sides can independently derive the DID

A shared test vector (`did:omnia:4bb06f8e4e3a7715d201d573d0aa4237` for a 32-byte `0x07` key) is asserted in both the wallet and node test suites to prevent implementation drift.

---

## 📝 Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `OMNIA_NODE_URL` | Base URL of Omnia node | Required |

### Runtime Configuration

- **Node endpoint**: Editable from Settings → Node endpoint (persisted on device)
- **Biometric lock**: Toggle in Settings → Security
- **Recovery phrase**: View in Settings → Security → Show recovery phrase

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. **Fork the repository** and create a feature branch
2. **Follow existing code style** and patterns
3. **Add tests** for new functionality
4. **Update documentation** as needed
5. **Submit a pull request** with clear description

### Development Workflow

```bash
# Create feature branch
git checkout -b feature/your-feature

# Make changes and test
flutter analyze
flutter test

# Commit changes
git commit -m "feat: add your feature"

# Push to fork
git push origin feature/your-feature
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- Built with [Flutter](https://flutter.dev) and [Dart](https://dart.dev)
- Uses [Inter](https://rsms.me/inter/) font family
- Special thanks to all contributors and the Omnia Protocol team

---

## 📞 Support

- **Repository**: [github.com/Willow7737/Omnia-Wallet](https://github.com/Willow7737/Omnia-Wallet)
- **Protocol**: [github.com/Willow7737/omnia-protocol](https://github.com/Willow7737/omnia-protocol)
- **Issues**: Please report bugs and feature requests via GitHub Issues
