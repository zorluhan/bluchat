# bluchat (iOS)

A privacy-first Bluetooth/Wi‑Fi mesh chat for iPhone inspired by the UI and features shown in the screenshots.

Features (MVP in this repo)
- Offline communication via Apple MultipeerConnectivity (Bluetooth LE / peer‑to‑peer Wi‑Fi / local network)
- Mesh relaying: nodes re‑broadcast unseen messages to extend range
- End‑to‑end encryption helpers: Curve25519 (X25519) + AES‑GCM (via CryptoKit)
- Rooms: create/join `#rooms` for topic‑based chats
- Mentions: `@nickname` highlighting in the UI
- Password rooms: derive a symmetric key from a room password (PBKDF2/HKDF) for AES‑GCM
- Ephemeral identity: random nickname persisted locally; no servers/accounts/analytics

What’s included
- SwiftUI app skeleton with chat UI and input bar
- MultipeerConnectivity mesh session with message relay + de‑duplication
- Crypto utilities for AES‑GCM and X25519 shared secret
- XcodeGen project spec (`project.yml`) so you can generate an Xcode project

Limitations
- Background performance and mesh reliability depend on iOS constraints for Bluetooth/Wi‑Fi.
- Store‑and‑forward/Favorites are sketched; production apps need persistence policies and delivery receipts.

Quick start
```bash
# 1) Install XcodeGen if you don’t have it
brew install xcodegen

# 2) Generate the Xcode project
cd bluchat
xcodegen generate

# 3) Open in Xcode, set Signing Team, run on real devices
open Bluchat.xcodeproj
```

App configuration
- Bundle ID in `project.yml`: `com.example.bluchat` (edit for your team)
- Info.plist already includes Bluetooth usage descriptions

Security
- Messages are encrypted with AES‑GCM using a per‑room symmetric key. For password rooms, the key is derived from the password.
- Device keys (X25519) can be used to negotiate session keys; see `CryptoManager`.

License
MIT
