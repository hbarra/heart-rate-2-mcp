"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.handleMcpRequest = handleMcpRequest;
const store_1 = require("./store");
const animals_1 = require("./animals");
// Tool definitions
const tools = [
    {
        name: 'getCurrentHeartRate',
        description: 'Get the current heart rate reading for a user',
        inputSchema: {
            type: 'object',
            properties: {
                pairingCode: {
                    type: 'string',
                    description: "The user's pairing code (e.g., tiger42)"
                }
            },
            required: ['pairingCode']
        }
    },
    {
        name: 'getHeartRateHistory',
        description: 'Get heart rate readings from the last N seconds',
        inputSchema: {
            type: 'object',
            properties: {
                pairingCode: {
                    type: 'string',
                    description: "The user's pairing code (e.g., tiger42)"
                },
                seconds: {
                    type: 'number',
                    description: 'Number of seconds of history to retrieve (1-1800)',
                    default: 10
                }
            },
            required: ['pairingCode']
        }
    },
    {
        name: 'getHeartRateStats',
        description: 'Get heart rate statistics (avg, min, max, time in each zone) for the last N seconds',
        inputSchema: {
            type: 'object',
            properties: {
                pairingCode: {
                    type: 'string',
                    description: "The user's pairing code (e.g., tiger42)"
                },
                seconds: {
                    type: 'number',
                    description: 'Number of seconds to calculate stats over (1-1800)',
                    default: 60
                }
            },
            required: ['pairingCode']
        }
    }
];
// Tool handlers
function handleGetCurrentHeartRate(pairingCode) {
    if (!(0, animals_1.isValidPairingCode)(pairingCode)) {
        return {
            content: [{ type: 'text', text: 'Invalid pairing code format. Expected format: animal + 2 digits (e.g., tiger42)' }],
            isError: true
        };
    }
    const reading = (0, store_1.getCurrentReading)(pairingCode);
    if (!reading) {
        return {
            content: [{ type: 'text', text: `No heart rate data available for ${pairingCode}. The user may not be connected or streaming.` }]
        };
    }
    const ageSeconds = Math.round((Date.now() - reading.timestamp.getTime()) / 1000);
    return {
        content: [{
                type: 'text',
                text: JSON.stringify({
                    bpm: reading.bpm,
                    zone: reading.zone,
                    timestamp: reading.timestamp.toISOString(),
                    ageSeconds,
                    summary: `Current heart rate: ${reading.bpm} BPM (Zone ${reading.zone}), ${ageSeconds}s ago`
                })
            }]
    };
}
function handleGetHeartRateHistory(pairingCode, seconds = 10) {
    if (!(0, animals_1.isValidPairingCode)(pairingCode)) {
        return {
            content: [{ type: 'text', text: 'Invalid pairing code format. Expected format: animal + 2 digits (e.g., tiger42)' }],
            isError: true
        };
    }
    const safeSeconds = Math.min(Math.max(seconds, 1), 1800);
    const readings = (0, store_1.getReadings)(pairingCode, safeSeconds);
    if (readings.length === 0) {
        return {
            content: [{ type: 'text', text: `No heart rate data in the last ${safeSeconds} seconds for ${pairingCode}.` }]
        };
    }
    const bpms = readings.map(r => r.bpm);
    const avgBpm = Math.round(bpms.reduce((a, b) => a + b, 0) / bpms.length);
    return {
        content: [{
                type: 'text',
                text: JSON.stringify({
                    count: readings.length,
                    avgBpm,
                    minBpm: Math.min(...bpms),
                    maxBpm: Math.max(...bpms),
                    readings: readings.map(r => ({
                        bpm: r.bpm,
                        zone: r.zone,
                        timestamp: r.timestamp.toISOString()
                    })),
                    summary: `${readings.length} readings in last ${safeSeconds}s. Average: ${avgBpm} BPM. Range: ${Math.min(...bpms)}-${Math.max(...bpms)} BPM.`
                })
            }]
    };
}
function handleGetHeartRateStats(pairingCode, seconds = 60) {
    if (!(0, animals_1.isValidPairingCode)(pairingCode)) {
        return {
            content: [{ type: 'text', text: 'Invalid pairing code format. Expected format: animal + 2 digits (e.g., tiger42)' }],
            isError: true
        };
    }
    const safeSeconds = Math.min(Math.max(seconds, 1), 1800);
    const stats = (0, store_1.getStats)(pairingCode, safeSeconds);
    if (!stats) {
        return {
            content: [{ type: 'text', text: `No heart rate data in the last ${safeSeconds} seconds for ${pairingCode}.` }]
        };
    }
    const zoneStr = Object.entries(stats.timeInZone)
        .filter(([_, count]) => count > 0)
        .map(([zone, count]) => `Z${zone}: ${count}s`)
        .join(', ');
    return {
        content: [{
                type: 'text',
                text: JSON.stringify({
                    ...stats,
                    summary: `Stats (last ${safeSeconds}s): Avg ${stats.avg} BPM, Min ${stats.min}, Max ${stats.max}. Time in zones: ${zoneStr || 'none'}`
                })
            }]
    };
}
// MCP JSON-RPC handler
async function handleMcpRequest(req, res) {
    try {
        const { method, params, id } = req.body;
        // Handle tools/list
        if (method === 'tools/list') {
            return res.json({
                jsonrpc: '2.0',
                result: { tools },
                id
            });
        }
        // Handle tools/call
        if (method === 'tools/call') {
            const { name, arguments: args } = params || {};
            let result;
            switch (name) {
                case 'getCurrentHeartRate':
                    result = handleGetCurrentHeartRate(args?.pairingCode);
                    break;
                case 'getHeartRateHistory':
                    result = handleGetHeartRateHistory(args?.pairingCode, args?.seconds);
                    break;
                case 'getHeartRateStats':
                    result = handleGetHeartRateStats(args?.pairingCode, args?.seconds);
                    break;
                default:
                    return res.json({
                        jsonrpc: '2.0',
                        error: { code: -32601, message: `Unknown tool: ${name}` },
                        id
                    });
            }
            return res.json({
                jsonrpc: '2.0',
                result,
                id
            });
        }
        // Handle initialize (for MCP protocol handshake)
        if (method === 'initialize') {
            return res.json({
                jsonrpc: '2.0',
                result: {
                    protocolVersion: '2024-11-05',
                    serverInfo: {
                        name: 'heart-rate-2-mcp',
                        version: '1.0.0'
                    },
                    capabilities: {
                        tools: {}
                    }
                },
                id
            });
        }
        // Unknown method
        res.json({
            jsonrpc: '2.0',
            error: { code: -32601, message: `Method not found: ${method}` },
            id
        });
    }
    catch (error) {
        console.error('MCP error:', error);
        res.status(500).json({
            jsonrpc: '2.0',
            error: { code: -32603, message: 'Internal server error' },
            id: req.body?.id || null
        });
    }
}
