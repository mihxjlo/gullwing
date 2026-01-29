<p align="center">
  <img src="assets/gullwinglogo.png" alt="Gullwing Logo" width="120" height="120">
</p>

<h1 align="center">ClipSync</h1>

<p align="center">
  <strong>Seamless cross-device clipboard synchronization</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#usage">Usage</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#tech-stack">Tech Stack</a>
</p>

---

## Overview

**ClipSync** is a Flutter-based clipboard synchronization application that enables real-time sharing of text, links, code snippets, images, and files across multiple devices. Built with Firebase backend, it provides instant sync capabilities with a beautiful, modern dark-themed UI.

Whether you're copying a URL from your laptop to paste on your phone, sharing code snippets between workstations, or transferring images and documents across devices, ClipSync makes cross-device clipboard sharing effortless.

---

## Features

### Core Sync
- 🔄 **Real-time Sync** — Clipboard content syncs instantly across all paired devices
- 📱 **Cross-platform** — Web and Android supported in MVP, with iOS and Desktop planned
- 🔗 **Session-based Pairing** — Secure 6-character code pairing system
- 🎛️ **Host Control** — Session creator is the admin; when host disconnects, all devices are disconnected

### Content Types
- 📝 **Text & Links** — Share text content with smart link detection
- 💻 **Code Snippets** — Code detection with syntax-aware display
- 🖼️ **Images** — Attach and sync images up to 10MB with thumbnail previews
- 📁 **Files** — Share any file type (PDF, documents, etc.) up to 10MB

### Input Modes
- ✍️ **Manual Input** — Type or paste content to sync without clipboard access
- 🤖 **Auto-detect Mode** — Optional automatic clipboard monitoring (Android)
- 📎 **Attach Media** — Pick images from gallery or files from device

### History & Management
- 📚 **Sync History** — View and manage all synced items within the session
- 🔍 **Full-screen Image Viewer** — View synced images in full resolution
- 💾 **Download Files** — Save synced images/files directly to device
- 🗑️ **Item Management** — Delete individual items or clear history

### UI/UX
- 🎨 **Modern Dark Theme** — Clean glassmorphic UI with smooth animations
- ⚡ **Instant Copy** — Tap any synced item to copy to local clipboard
- 📱 **Responsive Design** — Optimized for both mobile and web

---

## Screenshots

<p align="center">
  <i>Screenshots coming soon</i>
</p>

---

## Usage

### Pairing Devices

1. **Device A (Host)**:
   - Navigate to **Settings** → **Pair a Device**
   - Tap **Generate Pairing Code**
   - Share the 6-character code with Device B
   - *Note: The host controls the session — if host disconnects, all devices are disconnected*

2. **Device B (Guest)**:
   - Navigate to **Settings** → **Pair a Device**
   - Switch to **Join Session** tab
   - Enter the pairing code and tap **Connect**

3. Both devices will show "Connected" status once paired.

### Syncing Content

**Manual Sync (Text/Links/Code):**
1. Go to the **Live** screen
2. Type or paste content in the input field
3. Tap **Sync to All Devices**
4. Content appears on all paired devices instantly

**Attach Images:**
1. Tap **Attach Image** button on Live screen
2. Select image from gallery
3. Image uploads to cloud and syncs to all devices

**Attach Files:**
1. Tap **Attach File** button on Live screen
2. Select any file (PDF, document, etc.)
3. File uploads and syncs (max 10MB)

**Auto-detect Mode (Android):**
1. Go to **Settings** → **Sync Mode**
2. Enable **Auto-detect clipboard**
3. Clipboard changes are captured automatically

### Viewing & Downloading

**View History:**
- Navigate to the **History** tab
- Tap any item to expand and see full content
- Tap **Copy** to copy text to clipboard
- Tap **View** to open full-screen image viewer

**Download Files:**
- Expand item in History
- Tap **Save** button
- **Android**: File saved to Downloads folder
- **Web**: Browser download dialog opens

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
│   │              PairingService + StorageService               │ │
│   │         (Device Identity, Session State, File Upload)      │ │
│   └────────────────────────────┬───────────────────────────────┘ │
└────────────────────────────────┼────────────────────────────────┘
                                 │
┌────────────────────────────────▼────────────────────────────────┐
│                        DATA LAYER                                │
│                                                                   │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │          Firebase Firestore + Firebase Storage            │  │
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
| **Data** | Firebase Firestore, Storage | Persistent storage, real-time sync, file hosting |

---

## How Pairing Works

### Session Creation Flow

```
Device A (Host)                   Firebase                         Device B (Guest)
   │                                  │                                │
   │  1. Generate session + code      │                                │
   │─────────────────────────────────►│                                │
   │                                  │                                │
   │  2. Store session                │                                │
   │  {                               │                                │
   │    pairingCode: "ABC123"         │                                │
   │    hostDeviceId: deviceA         │                                │
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

### Host Disconnect Flow

```
Device A (Host)                   Firebase                         Device B (Guest)
   │                                  │                                │
   │  1. Leave session               │                                │
   │─────────────────────────────────►│                                │
   │                                  │                                │
   │  2. Detect host leaving          │                                │
   │     → Set isActive: false        │                                │
   │                                  │                                │
   │  3. Disconnected                 │  4. Stream update: !isActive  │
   │◄─────────────────────────────────│───────────────────────────────►│
   │                                  │                                │
   │                                  │  5. Auto-disconnect guest     │
   │                                  │───────────────────────────────►│
   ▼                                  ▼                                ▼
          Session closed. All devices return to disconnected state.
```

### Pairing Code Specification

- **Format**: 6 alphanumeric characters (A-Z, 0-9, excluding ambiguous I/O/0/1)
- **Expiration**: 5 minutes from generation
- **Refresh**: Users can generate a new code if expired

---

## How Clipboard Sync Works

### Text Sync Flow

```
User types/pastes "Hello World"
         │
         ▼
┌─────────────────────────────────────────────────────────────────┐
│  ClipboardBloc receives ClipboardManuallyAdded event            │
│                                                                  │
│  1. Create ClipboardItem:                                        │
│     {                                                            │
│       id: "uuid-1234",                                           │
│       content: "Hello World",                                    │
│       type: "text",                                              │
│       sourceDevice: "Pixel 7",                                   │
│       timestamp: now,                                            │
│       syncStatus: "synced"                                       │
│     }                                                            │
│                                                                  │
│  2. Write to Firestore: sessions/{id}/clipboard_items/{id}       │
└─────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────┐
│             Firebase Firestore (Real-time Database)              │
│                                                                  │
│  • Stores item in session's clipboard_items subcollection        │
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

### Media Sync Flow (Images/Files)

```
User attaches image/file
         │
         ▼
┌─────────────────────────────────────────────────────────────────┐
│  ClipboardBloc receives ClipboardImagePasted/FileAttached        │
│                                                                  │
│  1. Validate file size (≤ 10MB)                                  │
│  2. Upload to Firebase Storage:                                  │
│     sessions/{sessionId}/files/{timestamp}/{filename}            │
│  3. Generate thumbnail (for images)                              │
│  4. Get download URLs                                            │
└─────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────┐
│  Create ClipboardItem with media metadata:                       │
│  {                                                               │
│    type: "image" | "file",                                       │
│    fileName: "photo.jpg",                                        │
│    fileSize: 2048576,                                            │
│    mimeType: "image/jpeg",                                       │
│    downloadUrl: "https://storage.googleapis.com/...",            │
│    thumbnailUrl: "https://storage.googleapis.com/..."            │
│  }                                                               │
└─────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────┐
│  Other devices receive item and can:                             │
│  • View thumbnail preview                                        │
│  • Open full-screen image viewer                                 │
│  • Download file to device storage                               │
└─────────────────────────────────────────────────────────────────┘
```

### Session Isolation

Devices only receive clipboard items that belong to their session:

```dart
_firestore
  .collection('sessions')
  .doc(sessionId)
  .collection('clipboard_items')  // ← Session-scoped subcollection
  .orderBy('timestamp', descending: true)
  .snapshots()
```

This ensures complete isolation between different paired device groups.

---

## Tech Stack

| Category              | Technology |
|-----------------------|------------|
| **Framework**         | Flutter 3.x |
| **State Management**  | flutter_bloc ^9.x |
| **Backend**           | Firebase (Firestore, Auth, Storage) |
| **Local Storage**     | shared_preferences |
| **File Handling**     | file_picker, image_picker, http |
| **Networking**        | connectivity_plus |
| **Platform (MVP)**    | Android, Web |
| **Platform (Planned)**| iOS, Desktop |

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
│   │   ├── clipboard_item.dart   # Clipboard item model (text, image, file)
│   │   ├── connected_device.dart # Device model
│   │   └── pairing_session.dart  # Session model with host control
│   │
│   ├── screens/                  # UI screens
│   │   ├── live_screen.dart      # Live sync screen + media attach
│   │   ├── history_screen.dart   # Sync history + downloads
│   │   ├── settings_screen.dart  # App settings
│   │   └── pairing_screen.dart   # Device pairing
│   │
│   ├── services/                 # Business services
│   │   ├── firebase_service.dart # Firebase setup
│   │   ├── pairing_service.dart  # Device identity & session
│   │   ├── storage_service.dart  # Firebase Storage uploads
│   │   ├── download_service.dart # File downloads (Android/Web)
│   │   ├── settings_service.dart # User preferences
│   │   ├── clipboard_repository.dart
│   │   ├── device_repository.dart
│   │   └── session_repository.dart
│   │
│   ├── widgets/                  # Reusable components
│   │   ├── buttons.dart          # Custom buttons
│   │   ├── cards.dart            # Card components
│   │   ├── media_preview.dart    # Image/file preview widget
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
├── web/                          # Web config
├── pubspec.yaml                  # Dependencies
├── firestore.rules               # Firestore security rules
├── storage.rules                 # Firebase Storage security rules
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
  expiresAt: timestamp,       // Code expiration (createdAt + 5 min)
  deviceIds: string[],        // Array of device IDs in session
  hostDeviceId: string,       // Session admin - controls session lifecycle
  isActive: boolean           // Session active status
}

// sessions/{sessionId}/devices/{deviceId}
{
  name: string,               // Device name (e.g., "Pixel 7")
  type: string,               // "android" | "ios" | "web" | "desktop"
  lastSeen: timestamp,        // Last heartbeat
  status: string              // "active" | "idle" | "offline"
}

// sessions/{sessionId}/clipboard_items/{itemId}
{
  content: string,            // Clipboard content (text) or description
  type: string,               // "text" | "link" | "code" | "image" | "file"
  sourceDevice: string,       // Device name that created item
  timestamp: timestamp,       // Creation time
  syncStatus: string,         // "pending" | "syncing" | "synced" | "failed"
  
  // Media-specific fields (for image/file types)
  fileName: string,           // Original filename
  fileSize: number,           // File size in bytes
  mimeType: string,           // MIME type (e.g., "image/jpeg")
  downloadUrl: string,        // Firebase Storage download URL
  thumbnailUrl: string        // Thumbnail URL (for images)
}
```

---

## Security

- **Anonymous Authentication**: Firebase anonymous auth ensures all data access is authenticated
- **Session Isolation**: Clipboard items are filtered by sessionId, preventing cross-session data leaks
- **Host Control**: Only the session creator (host) can terminate the session for all devices
- **Short-lived Codes**: Pairing codes expire after 5 minutes
- **Storage Cleanup**: Media files are automatically deleted when sessions end
- **File Size Limits**: 10MB maximum file size to prevent abuse
- **User Control**: Devices can disconnect and clear session data at any time

---

## CI/CD

The project uses GitHub Actions for automated builds:

- **Android**: Builds APK and distributes via Firebase App Distribution
- **Web**: Builds and deploys to Firebase Hosting

Testers receive email notifications for new builds automatically.

---

## License

This project is private and not licensed for public use.
