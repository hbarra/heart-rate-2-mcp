"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.handleMcpRequest = handleMcpRequest;
const mcp_js_1 = require("@modelcontextprotocol/sdk/server/mcp.js");
const streamableHttp_js_1 = require("@modelcontextprotocol/sdk/server/streamableHttp.js");
const zod_1 = require("zod");
const store_1 = require("./store");
const animals_1 = require("./animals");
// Helper: Get connection status for a pairing code
function getConnectionStatus(pairingCode) {
    const reading = (0, store_1.getCurrentReading)(pairingCode);
    if (!reading) {
        return {
            connected: false,
            lastSeen: null,
            status: 'disconnected'
        };
    }
    const ageMs = Date.now() - reading.timestamp.getTime();
    const ageSeconds = Math.round(ageMs / 1000);
    // Streaming: data within last 10 seconds
    // Idle: data within last 60 seconds
    // Disconnected: no data or data older than 60 seconds
    let status;
    if (ageSeconds <= 10) {
        status = 'streaming';
    }
    else if (ageSeconds <= 60) {
        status = 'idle';
    }
    else {
        status = 'disconnected';
    }
    return {
        connected: status !== 'disconnected',
        lastSeen: reading.timestamp.toISOString(),
        status
    };
}
// Create MCP server instance
const getServer = () => {
    const server = new mcp_js_1.McpServer({
        name: 'heart-rate',
        version: '1.0.0'
    }, { capabilities: { tools: {} } });
    // Tool: Check connection status
    server.registerTool('checkConnection', {
        description: 'Check if a user is connected and streaming heart rate data. Call this before other tools to verify the user is active.',
        inputSchema: {
            pairingCode: zod_1.z.string().describe("The user's pairing code (e.g., condor34)")
        },
        outputSchema: {
            connected: zod_1.z.boolean().describe('Whether the user is connected'),
            lastSeen: zod_1.z.string().nullable().describe('ISO timestamp of last reading, or null if never connected'),
            status: zod_1.z.enum(['streaming', 'idle', 'disconnected']).describe('streaming = active data flow, idle = connected but no recent data, disconnected = no connection')
        }
    }, async ({ pairingCode }) => {
        if (!(0, animals_1.isValidPairingCode)(pairingCode)) {
            return {
                content: [{ type: 'text', text: 'Invalid pairing code format. Expected format: animal + 2 digits (e.g., condor34)' }],
                isError: true
            };
        }
        const result = getConnectionStatus(pairingCode);
        const statusText = result.status === 'streaming'
            ? 'User is actively streaming heart rate data.'
            : result.status === 'idle'
                ? 'User is connected but no recent data. They may have paused or backgrounded the app.'
                : 'User is not connected. No heart rate data available.';
        return {
            content: [{ type: 'text', text: statusText }],
            structuredContent: result
        };
    });
    // Tool: Get current heart rate
    server.registerTool('getHeartRate', {
        description: 'Get the current heart rate reading. Returns BPM, zone (1-5), and timestamp.',
        inputSchema: {
            pairingCode: zod_1.z.string().describe("The user's pairing code (e.g., condor34)")
        },
        outputSchema: {
            bpm: zod_1.z.number().describe('Heart rate in beats per minute'),
            zone: zod_1.z.number().describe('Heart rate zone (1-5)'),
            timestamp: zod_1.z.string().describe('ISO timestamp of the reading')
        }
    }, async ({ pairingCode }) => {
        if (!(0, animals_1.isValidPairingCode)(pairingCode)) {
            return {
                content: [{ type: 'text', text: 'Invalid pairing code format. Expected format: animal + 2 digits (e.g., condor34)' }],
                isError: true
            };
        }
        const reading = (0, store_1.getCurrentReading)(pairingCode);
        if (!reading) {
            return {
                content: [{ type: 'text', text: `No heart rate data available for ${pairingCode}. Use checkConnection to verify the user is streaming.` }],
                isError: true
            };
        }
        const result = {
            bpm: reading.bpm,
            zone: reading.zone,
            timestamp: reading.timestamp.toISOString()
        };
        return {
            content: [{ type: 'text', text: `Heart rate: ${result.bpm} BPM (Zone ${result.zone})` }],
            structuredContent: result
        };
    });
    // Tool: Get heart rate history
    server.registerTool('getHeartRateHistory', {
        description: 'Get heart rate readings from the last N seconds. Returns an array of readings for trend analysis.',
        inputSchema: {
            pairingCode: zod_1.z.string().describe("The user's pairing code (e.g., condor34)"),
            seconds: zod_1.z.number().min(1).max(1800).default(60).describe('Number of seconds of history to retrieve (1-1800, default: 60)')
        },
        outputSchema: {
            readings: zod_1.z.array(zod_1.z.object({
                bpm: zod_1.z.number(),
                timestamp: zod_1.z.string()
            })).describe('Array of heart rate readings')
        }
    }, async ({ pairingCode, seconds = 60 }) => {
        if (!(0, animals_1.isValidPairingCode)(pairingCode)) {
            return {
                content: [{ type: 'text', text: 'Invalid pairing code format. Expected format: animal + 2 digits (e.g., condor34)' }],
                isError: true
            };
        }
        const safeSeconds = Math.min(Math.max(seconds, 1), 1800);
        const readings = (0, store_1.getReadings)(pairingCode, safeSeconds);
        if (readings.length === 0) {
            return {
                content: [{ type: 'text', text: `No heart rate data in the last ${safeSeconds} seconds. Use checkConnection to verify the user is streaming.` }],
                isError: true
            };
        }
        const result = {
            readings: readings.map(r => ({
                bpm: r.bpm,
                timestamp: r.timestamp.toISOString()
            }))
        };
        return {
            content: [{ type: 'text', text: `Retrieved ${readings.length} readings from the last ${safeSeconds} seconds.` }],
            structuredContent: result
        };
    });
    // Tool: Get heart rate stats
    server.registerTool('getHeartRateStats', {
        description: 'Get heart rate statistics for the last N seconds. Includes average, min, max, and time spent in each zone.',
        inputSchema: {
            pairingCode: zod_1.z.string().describe("The user's pairing code (e.g., condor34)"),
            seconds: zod_1.z.number().min(1).max(1800).default(60).describe('Number of seconds to calculate stats over (1-1800, default: 60)')
        },
        outputSchema: {
            avg: zod_1.z.number().describe('Average BPM'),
            min: zod_1.z.number().describe('Minimum BPM'),
            max: zod_1.z.number().describe('Maximum BPM'),
            count: zod_1.z.number().describe('Number of readings'),
            timeInZone: zod_1.z.record(zod_1.z.string(), zod_1.z.number()).describe('Seconds spent in each zone (keys are zone numbers 1-5)')
        }
    }, async ({ pairingCode, seconds = 60 }) => {
        if (!(0, animals_1.isValidPairingCode)(pairingCode)) {
            return {
                content: [{ type: 'text', text: 'Invalid pairing code format. Expected format: animal + 2 digits (e.g., condor34)' }],
                isError: true
            };
        }
        const safeSeconds = Math.min(Math.max(seconds, 1), 1800);
        const stats = (0, store_1.getStats)(pairingCode, safeSeconds);
        if (!stats) {
            return {
                content: [{ type: 'text', text: `No heart rate data in the last ${safeSeconds} seconds. Use checkConnection to verify the user is streaming.` }],
                isError: true
            };
        }
        // Build zone summary
        const zoneEntries = Object.entries(stats.timeInZone)
            .filter(([_, count]) => count > 0)
            .map(([zone, count]) => `Zone ${zone}: ${count}s`);
        const zoneSummary = zoneEntries.length > 0 ? zoneEntries.join(', ') : 'no zone data';
        return {
            content: [{ type: 'text', text: `Stats (last ${safeSeconds}s): Avg ${stats.avg} BPM, Range ${stats.min}-${stats.max} BPM. Time in zones: ${zoneSummary}` }],
            structuredContent: stats
        };
    });
    return server;
};
// StreamableHTTP MCP handler for Dreamer compatibility
async function handleMcpRequest(req, res) {
    const server = getServer();
    try {
        const transport = new streamableHttp_js_1.StreamableHTTPServerTransport({
            sessionIdGenerator: undefined
        });
        await server.connect(transport);
        await transport.handleRequest(req, res, req.body);
        res.on('close', () => {
            transport.close();
            server.close();
        });
    }
    catch (error) {
        console.error('Error handling MCP request:', error);
        if (!res.headersSent) {
            res.status(500).json({
                jsonrpc: '2.0',
                error: {
                    code: -32603,
                    message: 'Internal server error'
                },
                id: null
            });
        }
    }
}
