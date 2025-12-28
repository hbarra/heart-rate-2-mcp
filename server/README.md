# Heart Rate 2 MCP - Server

Backend API and MCP server for streaming heart rate data from mobile devices to Dreamer agents.

## Endpoints

### REST API (for mobile app)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `POST /api/hr` | POST | Receive heart rate reading |
| `GET /api/hr/current?code=X` | GET | Get latest reading |
| `GET /api/hr/history?code=X&seconds=N` | GET | Get last N seconds of readings |
| `GET /api/hr/stats?code=X&seconds=N` | GET | Get stats for last N seconds |
| `GET /health` | GET | Health check |

### MCP (for Dreamer agents)

`POST /mcp` - MCP StreamableHTTP endpoint

**Tools:**
- `getCurrentHeartRate({ pairingCode })` - Get latest BPM and zone
- `getHeartRateHistory({ pairingCode, seconds })` - Get readings array
- `getHeartRateStats({ pairingCode, seconds })` - Get avg/min/max and time in zones

## Local Development

```bash
npm install
npm run dev
```

## Deploy to Render

1. Create new Web Service on Render
2. Connect GitHub repo
3. Build command: `npm install && npm run build`
4. Start command: `npm start`
5. No environment variables required

## Data Storage

- In-memory storage with 30-minute TTL
- Data does not persist across restarts
- No database required

## Pairing Code Format

`<animal><2-digit>` e.g., `tiger42`, `falcon07`

Valid animals: tiger, falcon, wolf, eagle, shark, lion, bear, hawk, fox, panther, cobra, raven, lynx, orca, viper, jaguar, condor, badger, raptor, phoenix
