# HR2MCP - Project Knowledge Base

## Project Overview

**HR2MCP** (Heart Rate 2 MCP) is a complete system that streams real-time heart rate data from Bluetooth chest strap monitors to AI agents via the Model Context Protocol (MCP). It consists of three components:

1. **Flutter Mobile App** (`hr2mcp_app/`) - iOS/Android app that connects to Bluetooth heart rate monitors
2. **Node.js Backend Server** (`server/`) - Receives heart rate data and exposes it via REST API and MCP
3. **Landing Page** (`server/public/`) - Marketing website at hr2mcp.com

---

## Architecture

```
┌─────────────────┐     HTTP POST      ┌─────────────────┐      MCP       ┌─────────────────┐
│  Flutter App    │ ─────────────────► │  Node.js Server │ ◄────────────► │   AI Agents     │
│  (iOS/Android)  │    /api/hr         │  (Render.com)   │                │ (Claude, etc.)  │
└─────────────────┘                    └─────────────────┘                └─────────────────┘
        │                                      │
        │ Bluetooth LE                         │ Stores latest
        ▼                                      ▼ heart rate in memory
┌─────────────────┐                    ┌─────────────────┐
│  Chest Strap    │                    │  Landing Page   │
│  HR Monitor     │                    │  hr2mcp.com     │
└─────────────────┘                    └─────────────────┘
```

---

## Live Deployment

| Component | URL | Platform |
|-----------|-----|----------|
| Website | https://hr2mcp.com | Cloudflare DNS → Render |
| API | https://hr2mcp.com/api/hr | Render Web Service |
| MCP Endpoint | https://hr2mcp.com/mcp | Render Web Service |
| Health Check | https://hr2mcp.com/health | Render Web Service |

**MCP Configuration for AI Clients:**
- Server URL: `https://hr2mcp.com/mcp`
- Authentication: None (bearer token: none)
- Pairing Code: `condor34`

---

## Repository Structure

```
heart-rate-2-mcp/
├── hr2mcp_app/                 # Flutter mobile app
│   ├── lib/
│   │   ├── main.dart           # App entry point, initialization
│   │   ├── screens/
│   │   │   ├── home_screen.dart    # Main UI with heart rate display
│   │   │   └── setup_screen.dart   # Initial setup wizard
│   │   └── services/
│   │       ├── api_service.dart        # HTTP communication with server
│   │       ├── heart_rate_service.dart # Bluetooth LE heart rate monitoring
│   │       └── zone_service.dart       # Heart rate zone calculations
│   ├── ios/
│   │   └── Runner/
│   │       └── Info.plist      # iOS permissions and config
│   ├── android/
│   │   └── app/src/main/
│   │       └── AndroidManifest.xml  # Android permissions
│   └── pubspec.yaml            # Flutter dependencies
│
├── server/                     # Node.js backend
│   ├── src/
│   │   ├── index.ts            # Express server entry point
│   │   ├── api.ts              # REST API routes (/api/hr)
│   │   └── mcp.ts              # MCP protocol handler
│   ├── public/
│   │   ├── index.html          # Landing page
│   │   └── icon.png            # App icon (512x512)
│   ├── dist/                   # Compiled JavaScript (generated)
│   ├── package.json            # Node dependencies
│   ├── tsconfig.json           # TypeScript config
│   └── render.yaml             # Render.com deployment config
│
├── .github/                    # GitHub config (if any)
└── README.md                   # Project readme
```

---

## Flutter App Details

### Dependencies (pubspec.yaml)
- `flutter_blue_plus` - Bluetooth LE communication
- `http` - HTTP requests to server
- `permission_handler` - Runtime permission requests
- `shared_preferences` - Local storage for settings

### Key Features
1. **Bluetooth Scanning** - Discovers heart rate monitors advertising HR service UUID `0x180D`
2. **Heart Rate Monitoring** - Subscribes to HR characteristic `0x2A37`
3. **Server Streaming** - POSTs heart rate data to server every update
4. **Test Mode** - Simulates heart rate data without a real device (for development)
5. **Heart Rate Zones** - Calculates zones based on user's max heart rate
6. **Setup Wizard** - Initial configuration for server URL and user settings

### iOS Permissions Required (Info.plist)
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>...</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>...</string>
```

### Android Permissions Required (AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
```

### Running the App
```bash
cd hr2mcp_app
flutter pub get
flutter run
```

---

## Server Details

### Technology Stack
- **Runtime**: Node.js with TypeScript
- **Framework**: Express.js
- **Build**: Pre-compiled to JavaScript (required for Render.com memory limits)
- **Hosting**: Render.com (Starter tier, $7/month)

### API Endpoints

#### POST /api/hr
Receives heart rate data from mobile app.

**Request:**
```json
{
  "heartRate": 72,
  "timestamp": "2024-01-15T10:30:00.000Z",
  "device": "Polar H10"
}
```

**Response:**
```json
{
  "success": true,
  "heartRate": 72,
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

#### GET /api/hr
Returns latest heart rate data.

**Response:**
```json
{
  "heartRate": 72,
  "timestamp": "2024-01-15T10:30:00.000Z",
  "device": "Polar H10",
  "age": 5
}
```

#### GET /health
Health check endpoint.

**Response:**
```json
{
  "status": "ok",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

#### POST /mcp
MCP protocol endpoint for AI agents.

### MCP Tools Exposed
1. **get_heart_rate** - Returns current heart rate, timestamp, device name, and data age
2. **get_heart_rate_zones** - Returns zone boundaries based on max HR (calculated using 220-age formula)
3. **get_heart_rate_history** - Returns array of recent heart rate readings

### Building and Running Server
```bash
cd server
npm install
npm run build    # Compiles TypeScript to dist/
npm start        # Runs compiled JavaScript
```

### Deployment Process
1. Push to GitHub `main` branch
2. Render.com auto-deploys from GitHub
3. Build command: `npm install && npm run build`
4. Start command: `npm start`

**Important**: Server must be pre-compiled before pushing because Render's free/starter tier has memory limits that cause TypeScript compilation to fail during deployment.

---

## Domain & DNS Setup

**Domain**: hr2mcp.com (registered via Cloudflare, ~$10/year)

**DNS Records (Cloudflare):**
| Type | Name | Target |
|------|------|--------|
| CNAME | @ | hr2mcp.onrender.com |
| CNAME | www | hr2mcp.onrender.com |

**SSL**: Automatically provisioned by Render.com

---

## Known Issues & Future Work

### Pending Improvements
1. **Background Bluetooth** - iOS app loses Bluetooth connection when backgrounded. Needs:
   - Add `bluetooth-central` to UIBackgroundModes in Info.plist
   - Add `wakelock_plus` package to prevent screen sleep
   - Add auto-reconnect logic in heart_rate_service.dart
   - Add WidgetsBindingObserver to track app lifecycle

2. **Custom App Icon** - Currently uses default Flutter icon. Icon file exists at `server/public/icon.png` (512x512 red heart with pulse line and "MCP" text). Needs flutter_launcher_icons setup.

3. **App Name** - Should be renamed from "Heart Rate 2 MCP" to "HR2MCP" in:
   - Info.plist (CFBundleDisplayName, CFBundleName)
   - AndroidManifest.xml (android:label)

### Completed Features
- ✅ Bluetooth heart rate monitor connection
- ✅ Real-time streaming to server
- ✅ MCP endpoint for AI agents
- ✅ Landing page at hr2mcp.com
- ✅ Test mode for development without hardware
- ✅ Heart rate zone calculations
- ✅ Setup wizard

---

## Development Commands

### Flutter App
```bash
cd hr2mcp_app
flutter pub get          # Install dependencies
flutter run              # Run on connected device
flutter build ios        # Build iOS app
flutter build apk        # Build Android APK
flutter clean            # Clean build artifacts
```

### Server
```bash
cd server
npm install              # Install dependencies
npm run build            # Compile TypeScript
npm start                # Start server
npm run dev              # Start with hot reload (if configured)
```

### Git
```bash
git add .
git commit -m "message"
git push                 # Triggers Render auto-deploy
```

---

## Environment & Tools

- **Flutter**: 3.x (latest stable)
- **Node.js**: 18.x or 20.x
- **TypeScript**: 5.x
- **Package Manager**: npm (server), pub (Flutter)
- **Hosting**: Render.com
- **DNS**: Cloudflare
- **Repository**: https://github.com/hbarra/heart-rate-2-mcp

---

## Contact & Context

This project was built for Hugo Barra as part of the /dev/agents platform exploration. The goal is to bridge physical sensors (heart rate monitors) with AI agents through the MCP protocol, enabling AI assistants to access real-time biometric data.

The primary use case is fitness coaching and health monitoring where an AI agent can:
- Monitor heart rate during workouts
- Provide real-time feedback based on heart rate zones
- Track cardiovascular trends over time
- Alert when heart rate is abnormally high or low
