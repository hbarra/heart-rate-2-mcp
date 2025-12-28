# Heart Rate 2 MCP

Stream real-time heart rate data from BLE chest straps to Dreamer agents via MCP.

## Architecture

```
┌─────────────────┐     1Hz      ┌─────────────────┐
│  Mobile App     │─────────────▶│  Backend + MCP  │
│  (Flutter)      │   POST /hr   │  (Render)       │
│                 │              │                 │
└─────────────────┘              └─────────────────┘
        │                               ▲
        │ BLE                           │ sdk.callTool
        ▼                               │
┌─────────────────┐              ┌─────────────────┐
│  Chest Strap    │              │  Dreamer Agent  │
│  (Garmin/Polar) │              │                 │
└─────────────────┘              └─────────────────┘
```

## Components

### Mobile App (Flutter)
- Connects to BLE heart rate monitors (Garmin, Polar, Wahoo, etc.)
- Calculates heart rate zones (age-based or manual)
- Streams BPM + zone to backend at 1Hz
- Generates and displays pairing code

### Backend + MCP Server (Node.js)
- Receives heart rate data from mobile apps
- Stores 30-minute rolling window (in-memory)
- Exposes MCP tools for Dreamer agents

## Pairing

Each app install generates a unique pairing code in format `<animal><2-digit>` (e.g., `tiger42`, `falcon07`).

Users tell their Dreamer agent: "My heart rate code is tiger42" and the agent stores it for future queries.

## MCP Tools

| Tool | Description |
|------|-------------|
| `getCurrentHeartRate` | Get latest BPM and zone |
| `getHeartRateHistory` | Get readings for last N seconds |
| `getHeartRateStats` | Get avg/min/max and time in zones |

### Example Usage

```typescript
// In a Dreamer agent
const result = await sdk.callTool('heart-rate-2-mcp', {
  tool: 'getCurrentHeartRate',
  arguments: { pairingCode: 'tiger42' }
});
// Returns: { bpm: 142, zone: 4, timestamp: "2024-01-15T10:23:45Z" }
```

## Setup

### 1. Deploy Server to Render

```bash
cd server
npm install
npm run build
```

On Render:
- Create new Web Service
- Connect GitHub repo
- Build command: `npm install && npm run build`
- Start command: `npm start`
- No environment variables needed

### 2. Build Mobile App

```bash
cd app
flutter pub get
flutter build ios --release
flutter build apk --release
```

### 3. Register MCP Tool with Dreamer

Register your deployed MCP endpoint (`https://your-app.onrender.com/mcp`) as a tool in Dreamer.

## Development

### Server

```bash
cd server
npm install
npm run dev
```

### Mobile App

```bash
cd app
flutter pub get
flutter run
```

The app includes a **Test Mode** button that simulates heart rate data without a physical chest strap.

## Heart Rate Zones

Zones are calculated from age using standard formula:
- Max HR = 220 - age
- Zone 1: 50-60% (Recovery)
- Zone 2: 60-70% (Aerobic)
- Zone 3: 70-80% (Tempo)
- Zone 4: 80-90% (Threshold)
- Zone 5: 90-100% (VO2 Max)

Users can also manually configure zone thresholds in the app settings.

## Supported Devices

Any BLE device advertising Heart Rate Service (0x180D):
- Garmin HRM-Pro, HRM-Dual
- Polar H10, H9, OH1
- Wahoo TICKR, TICKR X
- Most generic chest straps

## Data Retention

- Heart rate readings are kept for 30 minutes
- Data is stored in-memory (no database)
- Data does not persist across server restarts
