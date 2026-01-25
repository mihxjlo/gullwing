<p align="center">
  <img src="assets/gullwinglogo.png" alt="Gullwing Logo" width="120" height="120">
</p>

<h1 align="center">Gullwing</h1>

<p align="center">
  <strong>Seamless cross-device clipboard synchronization</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#tech-stack">Tech Stack</a>
</p>

---

## Overview

**ClipSync** is a Flutter-based clipboard synchronization application that enables real-time sharing of text, links, and code snippets across multiple devices. Built with Firebase backend, it provides instant sync capabilities with a beautiful, modern dark-themed UI.

Whether you're copying a URL from your laptop to paste on your phone, or sharing code snippets between workstations, ClipSync makes cross-device clipboard sharing effortless.

---

## Features

- 🔄 **Real-time Sync** — Clipboard content syncs instantly across all paired devices
- 📱 **Cross-platform** — Web and Android supported in MVP, with iOS and Desktop planned
- 🔗 **Session-based Pairing** — Secure 6-character code pairing system
- 📝 **Manual Input** — Type or paste content to sync without clipboard access
- 🤖 **Auto-detect Mode** — Optional automatic clipboard monitoring
- 📚 **Sync History** — View and manage recently synced items within the session
- 🎨 **Modern UI** — Clean dark theme with smooth animations
- ⚡ **Instant Copy** — Tap any synced item to copy to local clipboard

---

## Screenshots

<p align="center">
  <i>Screenshots coming soon</i>
</p>

---

## Prerequisites

Before running Gullwing, ensure you have the following installed:

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.0+)
- [Firebase CLI](https://firebase.google.com/docs/cli) (for deployment)
- Android Studio / Xcode (for mobile development)
- A Firebase project with Firestore and Authentication enabled

---

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/clipsync.git
cd clipsync
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Firebase Configuration

The app is pre-configured with Firebase. To use your own Firebase project:

1. Create a new Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Anonymous Authentication**
3. Create a **Cloud Firestore** database
4. Run FlutterFire CLI to configure:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

### 4. Run the App

```bash
# Run on connected device
flutter run

# Run on specific platform
flutter run -d chrome    # Web
flutter run -d android   # Android
```

---

## Usage

### Pairing Devices

1. **Device A (Host)**:
   - Navigate to **Settings** → **Pair a Device**
   - Tap **Generate Pairing Code**
   - Share the 6-character code with Device B

2. **Device B (Guest)**:
   - Navigate to **Settings** → **Pair a Device**
   - Switch to **Join Session** tab
   - Enter the pairing code and tap **Connect**

3. Both devices will show "Connected" status once paired.

### Syncing Content

**Manual Sync:**
1. Go to the **Live** screen
2. Type or paste content in the input field
3. Tap **Sync to All Devices**
4. Content appears on all paired devices instantly

**Auto-detect Mode:**
1. Go to **Settings** → **Sync Mode**
2. Enable **Auto-detect clipboard**
3. Clipboard changes are captured automatically

### Viewing History

- Navigate to the **History** tab
- Browse all previously synced items
- Tap any item to copy to clipboard
- Swipe to delete individual items

---

## Architecture

ClipSync follows a clean architecture pattern with three distinct layers:

```
┌─────────────────────────────────────────────────────────────────┐
│                      PRESENTATION LAYER                          │
│                                                                   │
│   ┌─────────────┐   ┌──────────────┐   ┌──────────────────┐     │
│   │ LiveScreen  │   │HistoryScreen │   │  SettingsScreen  │     │
│   └──────┬──────┘   └──────┬───────┘   └────────┬─────────┘     │
│          │                 │                    │                │
│          └─────────────────┼────────────────────┘                │
│                            ▼                                     │
│   ┌────────────────────────────────────────────────────────┐    │
│   │                    BLoC Layer                           │    │
│   │  ┌──────────┐  ┌──────────┐  ┌─────────┐  ┌─────────┐  │    │
│   │  │Clipboard │  │ Pairing  │  │ Devices │  │  Auth   │  │    │
│   │  │  Bloc    │  │  Bloc    │  │  Bloc   │  │  Bloc   │  │    │
│   │  └────┬─────┘  └────┬─────┘  └────┬────┘  └────┬────┘  │    │
│   └───────┼─────────────┼─────────────┼────────────┼───────┘    │
└───────────┼─────────────┼─────────────┼────────────┼────────────┘
            │             │             │            │
┌───────────▼─────────────▼─────────────▼────────────▼────────────┐
│                       DOMAIN LAYER                               │
│                                                                   │
│   ┌────────────────┐  ┌────────────────┐  ┌─────────────────┐   │
│   │ ClipboardRepo  │  │  SessionRepo   │  │   DeviceRepo    │   │
│   └───────┬────────┘  └───────┬────────┘  └────────┬────────┘   │
│           │                   │                    │             │
│   ┌───────▼───────────────────▼────────────────────▼──────────┐ │
│   │                    PairingService                          │ │
│   │              (Device Identity & Session State)             │ │
│   └────────────────────────────┬───────────────────────────────┘ │
└────────────────────────────────┼────────────────────────────────┘
                                 │
┌────────────────────────────────▼────────────────────────────────┐
│                        DATA LAYER                                │
│                                                                   │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │                   Firebase Firestore                      │  │
│   │  ┌───────────────┐ ┌───────────────┐ ┌─────────────────┐ │  │
│   │  │   sessions/   │ │   devices/    │ │ clipboard_items/│ │  │
│   │  └───────────────┘ └───────────────┘ └─────────────────┘ │  │
│   └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Layer Responsibilities

| Layer | Components | Purpose |
|-------|------------|---------|
| **Presentation** | Screens, Widgets | UI rendering, user interaction |
| **BLoC** | ClipboardBloc, PairingBloc, etc. | State management, business logic |
| **Domain** | Repositories, Services | Data orchestration, caching |
| **Data** | Firebase Firestore | Persistent storage, real-time sync |

---

## How Pairing Works

### Session Creation Flow

```
Device A                          Firebase                         Device B
   │                                  │                                │
   │  1. Generate session + code      │                                │
   │─────────────────────────────────►│                                │
   │                                  │                                │
   │  2. Store session                │                                │
   │  {                               │                                │
   │    pairingCode: "ABC123"         │                                │
   │    deviceIds: [deviceA]          │                                │
   │    expiresAt: now + 5min         │                                │
   │  }                               │                                │
   │                                  │                                │
   │  3. Display code to user         │                                │
   │◄─────────────────────────────────│                                │
   │                                  │                                │
   │                                  │  4. Query by code "ABC123"     │
   │                                  │◄───────────────────────────────│
   │                                  │                                │
   │                                  │  5. Add deviceB to session     │
   │                                  │  deviceIds: [deviceA, deviceB] │
   │                                  │───────────────────────────────►│
   │                                  │                                │
   │  6. Stream update received       │  7. Joined successfully       │
   │◄─────────────────────────────────│───────────────────────────────►│
   │                                  │                                │
   ▼                                  ▼                                ▼
        Both devices now share the same sessionId
         and can sync clipboard items in real-time
```

### Pairing Code Specification

- **Format**: 6 alphanumeric characters (A-Z, 0-9)
- **Expiration**: 5 minutes from generation
- **Single-use**: Code becomes invalid after successful join
- **Refresh**: Users can generate a new code if expired

---

## How Clipboard Sync Works

### Sync Flow

```
User copies "Hello World"
         │
         ▼
┌─────────────────────────────────────────────────────────────────┐
│  ClipboardBloc receives ClipboardItemDetected event             │
│                                                                  │
│  1. Create ClipboardItem:                                        │
│     {                                                            │
│       id: "uuid-1234",                                           │
│       content: "Hello World",                                    │
│       type: "text",                                              │
│       sessionId: "session-xyz",                                  │
│       sourceDevice: "Pixel 7",                                   │
│       timestamp: 2024-01-21T15:00:00Z                            │
│     }                                                            │
│                                                                  │
│  2. Write to Firestore: clipboard_items/{id}                     │
└─────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────┐
│             Firebase Firestore (Real-time Database)              │
│                                                                  │
│  • Stores item in clipboard_items collection                     │
│  • Triggers snapshot listeners on all connected clients          │
└─────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────┐
│  All paired devices receive stream update                        │
│                                                                  │
│  ClipboardRepository.watchItems(sessionId)                       │
│       │                                                          │
│       └──► Stream<List<ClipboardItem>> emits updated list        │
│                │                                                 │
│                └──► UI rebuilds with new item in "Latest Synced" │
└─────────────────────────────────────────────────────────────────┘
```

### Session Isolation

Devices only receive clipboard items that belong to their session:

```dart
_firestore
  .collection('clipboard_items')
  .where('sessionId', isEqualTo: currentSessionId)  // ← Session filter
  .orderBy('timestamp', descending: true)
  .snapshots()
```

This ensures complete isolation between different paired device groups.

---

## Tech Stack

| Category              | Technology |
|-----------------------|------------|
| **Framework**         | Flutter 3.x |
| **State Management**  | flutter_bloc ^8.x |
| **Backend**           | Firebase (Firestore, Auth) |
| **Local Storage**     | shared_preferences |
| **Equality**          | equatable |
| **Platform(MVP)**     | Android, Web |
| **Platform(Planned)** | iOS, Desktop |

---

## Project Structure

```
clipsync/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── firebase_options.dart     # Firebase configuration
│   │
│   ├── blocs/                    # State management
│   │   ├── auth/                 # Authentication BLoC
│   │   ├── clipboard/            # Clipboard sync BLoC
│   │   ├── devices/              # Connected devices BLoC
│   │   └── pairing/              # Session pairing BLoC
│   │
│   ├── models/                   # Data models
│   │   ├── clipboard_item.dart   # Clipboard item model
│   │   ├── connected_device.dart # Device model
│   │   └── pairing_session.dart  # Session model
│   │
│   ├── screens/                  # UI screens
│   │   ├── live_screen.dart      # Live sync screen
│   │   ├── history_screen.dart   # Sync history
│   │   ├── settings_screen.dart  # App settings
│   │   └── pairing_screen.dart   # Device pairing
│   │
│   ├── services/                 # Business services
│   │   ├── firebase_service.dart # Firebase setup
│   │   ├── pairing_service.dart  # Device identity
│   │   ├── settings_service.dart # User preferences
│   │   ├── clipboard_repository.dart
│   │   ├── device_repository.dart
│   │   └── session_repository.dart
│   │
│   ├── widgets/                  # Reusable components
│   │   ├── buttons.dart          # Custom buttons
│   │   ├── cards.dart            # Card components
│   │   └── common.dart           # Shared widgets
│   │
│   ├── theme/                    # Theming
│   │   ├── app_colors.dart       # Color palette
│   │   ├── app_theme.dart        # Theme data
│   │   └── app_typography.dart   # Text styles
│   │
│   └── navigation/               # Navigation
│       └── navigation_shell.dart # Bottom nav shell
│
├── android/                      # Android config
├── ios/                          # iOS config
├── web/                          # Web config
├── pubspec.yaml                  # Dependencies
└── README.md                     # This file
```

---

## Firestore Data Model

### Collections Schema

```javascript
// sessions/{sessionId}
{
  pairingCode: string,        // 6-char code (e.g., "ABC123")
  createdAt: timestamp,       // Session creation time
  codeExpiresAt: timestamp,   // Code expiration (createdAt + 5 min)
  deviceIds: string[],        // Array of device IDs in session
  isActive: boolean           // Session active status
}

// devices/{deviceId}
{
  name: string,               // Device name (e.g., "Pixel 7")
  type: string,               // "android" | "ios" | "web" | "desktop"
  sessionId: string,          // Current session ID
  lastSeen: timestamp,        // Last heartbeat
  status: string              // "active" | "idle" | "offline"
}

// clipboard_items/{itemId}
{
  content: string,            // Clipboard content
  type: string,               // "text" | "url" | "code"
  sessionId: string,          // Session this item belongs to
  sourceDevice: string,       // Device name that created item
  timestamp: timestamp        // Creation time
}
```

### Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Sessions: authenticated users can read/write
    match /sessions/{sessionId} {
      allow read, write: if request.auth != null;
    }
    
    // Devices: authenticated users can read/write
    match /devices/{deviceId} {
      allow read, write: if request.auth != null;
    }
    
    // Clipboard items: authenticated users can read/write
    match /clipboard_items/{itemId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

## Security

- **No user accounts**: No email, password, or persistent user profiles
- **Anonymous Authentication**: Firebase anonymous auth ensures all data access is authenticated
- **Session Isolation**: Clipboard items are filtered by sessionId, preventing cross-session data leaks
- **Short-lived Codes**: Pairing codes expire after 5 minutes
- **No Permanent Storage**: Users can disconnect and clear history at any time
- **User Control**: Devices can disconnect and clear session data at any time
- 
---


