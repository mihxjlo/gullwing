<p align="center">
  <img src="assets/gullwinglogo.png" alt="ClipSync Logo" width="120" height="120">
</p>

<h1 align="center">ClipSync</h1>

<p align="center">
  <strong>Seamless cross-device clipboard synchronization</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#platforms">Platforms</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#pairing-modes">Pairing Modes</a> •
  <a href="#sync-flow">Sync Flow</a>
</p>

---

## Overview

**ClipSync** is a Flutter-based clipboard synchronization application that enables real-time sharing of text, links, code snippets, images, and files across multiple devices. With support for multiple sync routes—Firebase cloud, LAN, and offline Nearby Connections—ClipSync ensures your clipboard is always in sync.

---

## Features

### Multi-Route Sync
- 🌐 **Firebase Cloud** — Works anywhere with internet connectivity
- 📡 **LAN Sync** — Direct local network sync for faster transfers
- 📱 **Nearby Connections** — Offline Android-to-Android sync via Bluetooth/Wi-Fi Direct
- 🔄 **Smart Route Selection** — Automatically uses the fastest available route

### Device Discovery
- 🔍 **UDP Broadcast Discovery** — Devices find each other automatically on local network
- 🛎️ **Invitation System** — Visual accept/decline prompts for incoming connections
- 🔗 **Code-based Pairing** — Secure 6-character code for cross-network pairing

### Content Types
- 📝 **Text & Links** — Smart link detection with syntax highlighting
- 💻 **Code Snippets** — Automatic code detection
- 🖼️ **Images** — Up to 10MB with thumbnail previews
- 📁 **Files** — Share PDFs, documents, and more (up to 10MB)

### Security & Control
- 🔐 **Session-based Pairing** — All data scoped to your session
- 👑 **Host Control** — Session creator manages the session lifecycle
- ⏱️ **Short-lived Codes** — Pairing codes expire after 5 minutes
- 🗑️ **Auto-cleanup** — Media files deleted when sessions end

---

## Platforms

| Platform | Status | Sync Routes |
|----------|--------|-------------|
| **Android** | ✅ Production | Firebase + LAN + Nearby |
| **Windows** | ✅ Production | Firebase + LAN |
| **Web** | ✅ Production | Firebase only |
| **macOS** | 🧪 Beta | Firebase + LAN |
| **Linux** | 🧪 Beta | Firebase + LAN |
| **iOS** | 📋 Planned | — |

> **Note:** Web uses Firebase-only sync. LAN and Nearby features require native socket/Bluetooth APIs not available in browsers.

---

## Quick Start

### Option 1: LAN Discovery (No Code Required)

1. Install ClipSync on both devices and connect to the **same Wi-Fi network**
2. Open the app → tap **Connect** button in header
3. Devices appear automatically via UDP broadcast
4. Tap a device → accept the invitation on target device
5. Session is created and devices are synced!

### Option 2: Code-based Pairing (Different Networks)

**Device A (Host):**
1. Go to **Settings** → **Pair a Device**
2. Tap **Generate Pairing Code**
3. Share the 6-character code (expires in 5 min)

**Device B (Guest):**
1. Go to **Settings** → **Pair a Device**
2. Switch to **Join Session** tab
3. Enter the code and tap **Connect**

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     SYNC MANAGER (SyncManager)                   │
│                                                                   │
│  Intelligent route selection: Firebase → LAN → Nearby → Queue    │
└───────────────────────────────┬───────────────────────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
        ▼                       ▼                       ▼
┌───────────────┐       ┌───────────────┐       ┌───────────────┐
│   Firebase    │       │  LAN Service  │       │Nearby Service │
│   (Cloud)     │       │  (WebSocket)  │       │ (P2P Offline) │
├───────────────┤       ├───────────────┤       ├───────────────┤
│ • Firestore   │       │ • WS Server   │       │ • Bluetooth   │
│ • Storage     │       │ • UDP Disco.  │       │ • Wi-Fi Direct│
│ • Auth        │       │ • Invitation  │       │ • Android only│
└───────────────┘       └───────────────┘       └───────────────┘
```

---

## Pairing Modes

ClipSync supports three distinct pairing modes, each optimized for different scenarios.

### Mode 1: LAN Discovery (UDP Broadcast)

Devices on the same local network discover each other automatically without needing a pairing code.

```
Device A (Android/Windows)              Network               Device B (Android/Windows)
         │                                 │                           │
         │  1. App starts                  │                           │
         │  ──► Start WebSocket server     │                           │
         │  ──► Start UDP broadcast        │                           │
         │                                 │                           │
         │  2. UDP Broadcast               │                           │
         │  "clipsync_announce"            │                           │
         │  {deviceId, name, ip, port}     │                           │
         │─────────────────────────────────┼──────────────────────────►│
         │                                 │                           │
         │                                 │    3. Device discovered   │
         │                                 │       in Connect modal    │
         │                                 │                           │
         │                       4. User taps to connect               │
         │◄────────────────────────────────┼───────────────────────────│
         │                                 │                           │
         │  5. Create session in Firebase  │                           │
         │─────────────────────────────────►                           │
         │                                 │                           │
         │  6. Send UDP invitation         │                           │
         │  "clipsync_invite"              │                           │
         │  {sessionId, hostName, hostIp}  │                           │
         │─────────────────────────────────┼──────────────────────────►│
         │                                 │                           │
         │                                 │    7. Invitation banner   │
         │                                 │       "Accept/Decline"    │
         │                                 │                           │
         │                       8. User accepts invitation            │
         │                                 │◄──────────────────────────│
         │                                 │                           │
         │                                 │    9. Join session by ID  │
         │                                 │       (Firebase)          │
         │                                 │                           │
         ▼                                 ▼                           ▼
              Both devices now in same session, clipboard synced
```

**Key Components:**
- `DiscoveryService` — UDP broadcast/listen on port 8766
- `LanService` — WebSocket server on port 8765
- `InvitationBanner` — UI for accept/decline

---

### Mode 2: Code-Based Pairing (Firebase)

Used when devices are on different networks or UDP discovery fails.

```
Device A (Host)                    Firebase                    Device B (Guest)
      │                               │                              │
      │  1. Generate session          │                              │
      │─────────────────────────────► │                              │
      │                               │                              │
      │  2. Store session:            │                              │
      │     {                         │                              │
      │       pairingCode: "ABC123"   │                              │
      │       hostDeviceId: deviceA   │                              │
      │       deviceIds: [deviceA]    │                              │
      │       expiresAt: now + 5min   │                              │
      │     }                         │                              │
      │                               │                              │
      │  3. Display code "ABC123"     │                              │
      │◄───────────────────────────── │                              │
      │                               │                              │
      │      ═══════════════════      │    4. User enters "ABC123"   │
      │       User shares code        │ ◄─────────────────────────── │
      │      ═══════════════════      │                              │
      │                               │    5. Query pairing_codes/   │
      │                               │       ABC123                 │
      │                               │ ◄──────────────────────────  │
      │                               │                              │
      │                               │    6. Get sessionId, join    │
      │                               │       deviceIds += deviceB   │
      │                               │ ─────────────────────────►   │
      │                               │                              │
      │  7. Stream: deviceIds changed │    8. Joined successfully    │
      │◄───────────────────────────── │ ─────────────────────────►   │
      │                               │                              │
      ▼                               ▼                              ▼
           Both devices share sessionId, real-time sync active
```

**Key Components:**
- `PairingService` — Session creation and code generation
- `SessionRepository` — Firebase Firestore operations
- `PairingBloc` — State management for pairing flow

---

### Mode 3: Nearby Connections (Offline P2P)

Android-only offline sync using Bluetooth and Wi-Fi Direct.

```
Device A (Android)                                   Device B (Android)
      │                                                    │
      │  1. Start advertising                              │
      │     (Bluetooth + Wi-Fi Direct)                     │
      │ ─────────────────────────────────────────────────► │
      │                                                    │
      │                                    2. Discover device
      │                                       in Connect modal
      │                                                    │
      │                            3. Request connection   │
      │ ◄───────────────────────────────────────────────── │
      │                                                    │
      │  4. Connection dialog                              │
      │     "Accept/Reject?"                               │
      │                                                    │
      │  5. Accept connection                              │
      │ ─────────────────────────────────────────────────► │
      │                                                    │
      │  ◄═══════════════════════════════════════════════► │
      │         P2P channel established                    │
      │         (No internet required)                     │
      │                                                    │
      │  6. Exchange clipboard data                        │
      │ ◄───────────────────────────────────────────────►  │
      │                                                    │
      ▼                                                    ▼
          Direct device-to-device sync, no server needed
```

**Key Components:**
- `NearbyService` — Google Nearby Connections API wrapper
- `ConnectionRequestDialog` — Accept/reject UI
- Only available on Android (requires Google Play Services)

---

## Sync Flow

### Smart Route Selection

The SyncManager automatically selects the best available route for each sync operation.

```
┌─────────────────────────────────────────────────────────────┐
│                    User syncs content                        │
│                  "Hello World" → Sync                        │
└─────────────────────────────┬───────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      SyncManager                             │
│                                                              │
│   ┌──────────────────────────────────────────────────────┐  │
│   │  Route Priority Check:                                │  │
│   │                                                       │  │
│   │  1. LAN connected?  ──────────► Use WebSocket (fast)  │  │
│   │         │                                             │  │
│   │         ▼ No                                          │  │
│   │  2. Nearby connected? ────────► Use P2P (offline)     │  │
│   │         │                                             │  │
│   │         ▼ No                                          │  │
│   │  3. Internet available? ──────► Use Firebase (cloud)  │  │
│   │         │                                             │  │
│   │         ▼ No                                          │  │
│   │  4. Queue for later ──────────► Offline queue (Hive)  │  │
│   └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Text/Link Sync Flow

```
User types "Hello World"
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│  ClipboardBloc receives ClipboardManuallyAdded event         │
│                                                              │
│  1. Create ClipboardItem:                                    │
│     {                                                        │
│       id: "uuid-1234",                                       │
│       content: "Hello World",                                │
│       type: "text",                                          │
│       sourceDevice: "Pixel 7",                               │
│       timestamp: now                                         │
│     }                                                        │
│                                                              │
│  2. SyncManager.sendItem(item)                               │
│     → Route selection (see above)                            │
│     → Write to selected route                                │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│  Other devices receive via:                                  │
│                                                              │
│  • Firebase: Firestore snapshot listener                     │
│  • LAN: WebSocket message                                    │
│  • Nearby: P2P payload                                       │
│                                                              │
│  ClipboardRepository.watchItems() → Stream<List<Item>>       │
│  UI rebuilds with new item in "Latest Synced"                │
└─────────────────────────────────────────────────────────────┘
```

### Image/File Sync Flow

```
User attaches image
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│  1. Validate file size (≤ 10MB)                              │
│  2. Upload to Firebase Storage:                              │
│     sessions/{sessionId}/files/{timestamp}/{filename}        │
│  3. Generate thumbnail (images only)                         │
│  4. Get download URLs                                        │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│  Create ClipboardItem with media metadata:                   │
│  {                                                           │
│    type: "image",                                            │
│    fileName: "photo.jpg",                                    │
│    fileSize: 2048576,                                        │
│    mimeType: "image/jpeg",                                   │
│    downloadUrl: "https://storage.googleapis.com/...",        │
│    thumbnailUrl: "https://storage.googleapis.com/..."        │
│  }                                                           │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│  Other devices can:                                          │
│  • View thumbnail preview                                    │
│  • Open full-screen image viewer                             │
│  • Download file to device storage                           │
└─────────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── blocs/                    # State management (BLoC)
│   ├── clipboard/            # Clipboard sync
│   ├── pairing/              # Session management
│   ├── devices/              # Connected devices
│   └── auth/                 # Firebase auth
├── services/                 # Business logic
│   ├── sync_manager.dart     # Multi-route sync orchestrator
│   ├── lan_service.dart      # WebSocket LAN sync
│   ├── discovery_service.dart # UDP broadcast discovery
│   ├── nearby_service.dart   # Offline P2P sync (Android)
│   └── ...                   # Firebase, storage, etc.
├── models/                   # Data models
├── screens/                  # UI screens
├── widgets/                  # Reusable components
└── theme/                    # App theming
```

---

## Tech Stack

| Category | Technology |
|----------|------------|
| **Framework** | Flutter 3.x |
| **State** | flutter_bloc |
| **Backend** | Firebase (Firestore, Storage, Auth) |
| **LAN Sync** | shelf, web_socket_channel |
| **Offline Sync** | nearby_connections |
| **Discovery** | UDP Broadcast (RawDatagramSocket) |

---

## Firestore Data Model

```javascript
// sessions/{sessionId}
{
  pairingCode: string,        // 6-char code (e.g., "ABC123")
  hostDeviceId: string,       // Session admin device
  deviceIds: string[],        // All devices in session
  isActive: boolean,          // Session status
  expiresAt: timestamp        // Code expiration
}

// sessions/{sessionId}/devices/{deviceId}
{
  name: string,               // "Pixel 7", "Windows PC"
  type: string,               // "android" | "windows" | "web"
  localIp: string,            // For LAN discovery
  lanPort: number,            // WebSocket port
  lastSeen: timestamp         // Heartbeat
}

// sessions/{sessionId}/clipboard_items/{itemId}
{
  content: string,            // Text content
  type: string,               // "text" | "link" | "image" | "file"
  sourceDevice: string,       // Origin device name
  timestamp: timestamp,       // Creation time
  downloadUrl: string,        // Media URL (optional)
  thumbnailUrl: string        // Thumbnail URL (optional)
}
```

---

## CI/CD

GitHub Actions workflows:
- **Android** — Builds APK, distributes via Firebase App Distribution
- **Web** — Builds and deploys to Firebase Hosting

Testers receive automatic email notifications for new builds.

---

## License

This project is private and not licensed for public use.
