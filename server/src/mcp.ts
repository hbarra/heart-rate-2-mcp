import { Request, Response } from 'express';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { z } from 'zod';
import { getCurrentReading, getReadings, getStats } from './store';
import { isValidPairingCode } from './animals';

// Helper: Get connection status for a pairing code
function getConnectionStatus(pairingCode: string): {
  connected: boolean;
  lastSeen: string | null;
  status: 'streaming' | 'idle' | 'disconnected';
} {
  const reading = getCurrentReading(pairingCode);

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
  let status: 'streaming' | 'idle' | 'disconnected';
  if (ageSeconds <= 10) {
    status = 'streaming';
  } else if (ageSeconds <= 60) {
    status = 'idle';
  } else {
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
  const server = new McpServer({
    name: 'heart-rate',
    version: '1.0.0'
  }, { capabilities: { tools: {} } });

  // Tool: Check connection status
  server.registerTool(
    'checkConnection',
    {
      description: 'Check if a user is connected and streaming heart rate data. Call this before other tools to verify the user is active.',
      inputSchema: {
        pairingCode: z.string().describe("The user's pairing code (e.g., condor34)")
      },
      outputSchema: {
        connected: z.boolean().describe('Whether the user is connected'),
        lastSeen: z.string().nullable().describe('ISO timestamp of last reading, or null if never connected'),
        status: z.enum(['streaming', 'idle', 'disconnected']).describe('streaming = active data flow, idle = connected but no recent data, disconnected = no connection')
      }
    },
    async ({ pairingCode }) => {
      if (!isValidPairingCode(pairingCode)) {
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
    }
  );

  // Tool: Get current heart rate
  server.registerTool(
    'getHeartRate',
    {
      description: 'Get the current heart rate reading. Returns BPM, zone (1-5), and timestamp.',
      inputSchema: {
        pairingCode: z.string().describe("The user's pairing code (e.g., condor34)")
      },
      outputSchema: {
        bpm: z.number().describe('Heart rate in beats per minute'),
        zone: z.number().describe('Heart rate zone (1-5)'),
        timestamp: z.string().describe('ISO timestamp of the reading')
      }
    },
    async ({ pairingCode }) => {
      if (!isValidPairingCode(pairingCode)) {
        return {
          content: [{ type: 'text', text: 'Invalid pairing code format. Expected format: animal + 2 digits (e.g., condor34)' }],
          isError: true
        };
      }

      const reading = getCurrentReading(pairingCode);
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
    }
  );

  // Tool: Get heart rate history
  server.registerTool(
    'getHeartRateHistory',
    {
      description: 'Get heart rate readings from the last N seconds. Returns an array of readings for trend analysis.',
      inputSchema: {
        pairingCode: z.string().describe("The user's pairing code (e.g., condor34)"),
        seconds: z.number().min(1).max(1800).default(60).describe('Number of seconds of history to retrieve (1-1800, default: 60)')
      },
      outputSchema: {
        readings: z.array(z.object({
          bpm: z.number(),
          timestamp: z.string()
        })).describe('Array of heart rate readings')
      }
    },
    async ({ pairingCode, seconds = 60 }) => {
      if (!isValidPairingCode(pairingCode)) {
        return {
          content: [{ type: 'text', text: 'Invalid pairing code format. Expected format: animal + 2 digits (e.g., condor34)' }],
          isError: true
        };
      }

      const safeSeconds = Math.min(Math.max(seconds, 1), 1800);
      const readings = getReadings(pairingCode, safeSeconds);

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
    }
  );

  // Tool: Get heart rate stats
  server.registerTool(
    'getHeartRateStats',
    {
      description: 'Get heart rate statistics for the last N seconds. Includes average, min, max, and time spent in each zone.',
      inputSchema: {
        pairingCode: z.string().describe("The user's pairing code (e.g., condor34)"),
        seconds: z.number().min(1).max(1800).default(60).describe('Number of seconds to calculate stats over (1-1800, default: 60)')
      },
      outputSchema: {
        avg: z.number().describe('Average BPM'),
        min: z.number().describe('Minimum BPM'),
        max: z.number().describe('Maximum BPM'),
        count: z.number().describe('Number of readings'),
        timeInZone: z.record(z.string(), z.number()).describe('Seconds spent in each zone (keys are zone numbers 1-5)')
      }
    },
    async ({ pairingCode, seconds = 60 }) => {
      if (!isValidPairingCode(pairingCode)) {
        return {
          content: [{ type: 'text', text: 'Invalid pairing code format. Expected format: animal + 2 digits (e.g., condor34)' }],
          isError: true
        };
      }

      const safeSeconds = Math.min(Math.max(seconds, 1), 1800);
      const stats = getStats(pairingCode, safeSeconds);

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
    }
  );

  return server;
};

// StreamableHTTP MCP handler for Dreamer compatibility
export async function handleMcpRequest(req: Request, res: Response) {
  const server = getServer();

  try {
    const transport = new StreamableHTTPServerTransport({
      sessionIdGenerator: undefined
    });

    await server.connect(transport);
    await transport.handleRequest(req, res, req.body);

    res.on('close', () => {
      transport.close();
      server.close();
    });
  } catch (error) {
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
