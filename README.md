# NearDrop

A high-performance, cross-platform file-sharing app built with Flutter — Wi-Fi
Direct / mDNS / WebRTC hybrid transfer, AES-256-GCM end-to-end encryption, and
a "Link to Windows"-style NearLink layer (clipboard sync + notification
mirroring) between mobile and desktop.

## Project layout

```
neardrop/
├── lib/
│   ├── core/
│   │   ├── network/        # Smart Switch, socket + WebRTC transfer channels, signaling client
│   │   ├── security/       # AES-256-GCM encryption, X25519 pairing/handshake
│   │   ├── database/       # Isar models (peers, transfer history)
│   │   ├── theme/          # Brand colors, typography
│   │   └── ...
│   ├── features/
│   │   ├── discovery/      # mDNS peer discovery, Bento dashboard UI
│   │   ├── transfer/       # Chunked encrypted file transfer engine + history UI
│   │   ├── link/           # NearLink: QR pairing, clipboard sync, notification mirroring
│   │   └── settings/
│   └── main.dart
├── signaling_server/        # Node.js WebSocket signaling server for the WebRTC relay path
├── assets/
└── pubspec.yaml
```

## Prerequisites

- Flutter 3.x (`flutter --version`)
- Dart 3.3+
- Node.js 18+ (for the signaling server, only needed for the relay/offline-network path)
- Platform toolchains as needed: Android Studio/SDK, Xcode, or the Windows/Linux desktop toolchain

## Getting started

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs   # generates Isar .g.dart files
flutter run -d windows   # or macos / linux / android / ios / chrome
```

## Running the signaling server locally

```bash
cd signaling_server
npm install
npm start          # listens on :8080
```

Point the app's `SignalingClient(serverUrl: 'ws://<host>:8080', ...)` at this
server for cross-network (relay) transfers. Local same-network transfers
never touch the signaling server — the Smart Switch routes those directly.

## Building for release

```bash
# Android
flutter build appbundle --release

# iOS
flutter build ipa --release

# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux
flutter build linux --release
```

## Deploying the signaling server

A `Dockerfile` is included:

```bash
cd signaling_server
docker build -t neardrop-signaling .
docker run -p 8080:8080 neardrop-signaling
```

Deploy that container to any host (Fly.io, Render, a VPS, etc.) and put it
behind TLS (wss://) for production — most PaaS providers terminate TLS for
you automatically.

## Platform-specific setup still required

These pieces depend on native code that can't ship as pure Dart and need to
be added per-platform before NearLink notification mirroring works:

- **Android**: a `NotificationListenerService` in
  `android/app/src/main/kotlin/.../NotificationListener.kt`, declared in
  `AndroidManifest.xml` with `android.permission.BIND_NOTIFICATION_LISTENER_SERVICE`,
  bridged to Dart via the `neardrop/notifications` MethodChannel referenced
  in `lib/features/link/data/notification_mirror_service.dart`.
- **Android**: Wi-Fi Direct (`WifiP2pManager`) native bridge if you want true
  Wi-Fi Direct rather than relying on local-subnet sockets — currently the
  Smart Switch uses plain local-network sockets, which works on shared Wi-Fi
  but not ad-hoc Wi-Fi Direct groups without an additional platform channel.
- **iOS**: Local Network permission (`NSLocalNetworkUsageDescription`) and
  Bonjour service types in `Info.plist` for mDNS discovery.
- **Desktop (Windows/macOS/Linux)**: notification display uses
  `local_notifier`, which works out of the box; no extra native code needed.

## Security notes

- Each transfer/NearLink session uses a fresh AES-256-GCM key derived via
  X25519 ECDH + HKDF from the QR-exchanged public keys (see
  `lib/core/security/pairing_service.dart`). The AES key itself is never
  transmitted.
- The signaling server only relays opaque SDP/ICE payloads between exactly
  two peers per room; it never sees file contents or the session key.

## License

Proprietary — internal project blueprint, ATC final-year build.
