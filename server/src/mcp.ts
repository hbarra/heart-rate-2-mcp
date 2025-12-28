import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { z } from 'zod';
import { Request, Response } from 'express';
import { getCurrentReading, getReadings, getStats } from './store';
import { isValidPairingCode } from './animals';

export function createMcpServer(): McpServer {
  const server = new McpServer(
    {
      name: 'heart-rate-2-mcp',
      version: '1.0.0'
    },
    { capabilities: { tools: {} } }
  );

  // Tool: Get current heart rate
  server.tool(
    'getCurrentHeartRate',
    'Get the current heart rate reading for a user',
    {
      pairingCode: z.string().describe('The user\'s pairing code (e.g., tiger42)')
    },
    async ({ pairingCode }) => {
      if (!isValidPairingCode(pairingCode)) {
        return {
          content: [{ type: 'text', text: 'Invalid pairing code format. Expected format: animal + 2 digits (e.g., tiger42)' }],
          isError: true
        };
      }

      const reading = getCurrentReading(pairingCode);

      if (!reading) {
        return {
          content: [{ type: 'text', text: `No heart rate data available for ${pairingCode}. The user may not be connected or streaming.` }]
        };
      }

      const ageSeconds = Math.round((Date.now() - reading.timestamp.getTime()) / 1000);
      
      return {
        content: [{
          type: 'text',
          text: `Current heart rate: ${reading.bpm} BPM (Zone ${reading.zone}), ${ageSeconds}s ago`
        }],
        structuredContent: {
          bpm: reading.bpm,
          zone: reading.zone,
          timestamp: reading.timestamp.toISOString()
        }
      };
    }
  );

  // Tool: Get heart rate history
  server.tool(
    'getHeartRateHistory',
    'Get heart rate readings from the last N seconds',
    {
      pairingCode: z.string().describe('The user\'s pairing code (e.g., tiger42)'),
      seconds: z.number().min(1).max(1800).default(10).describe('Number of seconds of history to retrieve (1-1800)')
    },
    async ({ pairingCode, seconds }) => {
      if (!isValidPairingCode(pairingCode)) {
        return {
          content: [{ type: 'text', text: 'Invalid pairing code format. Expected format: animal + 2 digits (e.g., tiger42)' }],
          isError: true
        };
      }

      const readings = getReadings(pairingCode, seconds);

      if (readings.length === 0) {
        return {
          content: [{ type: 'text', text: `No heart rate data in the last ${seconds} seconds for ${pairingCode}.` }]
        };
      }

      const bpms = readings.map(r => r.bpm);
      const avgBpm = Math.round(bpms.reduce((a, b) => a + b, 0) / bpms.length);

      return {
        content: [{
          type: 'text',
          text: `${readings.length} readings in last ${seconds}s. Average: ${avgBpm} BPM. Range: ${Math.min(...bpms)}-${Math.max(...bpms)} BPM.`
        }],
        structuredContent: {
          readings: readings.map(r => ({
            bpm: r.bpm,
            zone: r.zone,
            timestamp: r.timestamp.toISOString()
          }))
        }
      };
    }
  );

  // Tool: Get heart rate stats
  server.tool(
    'getHeartRateStats',
    'Get heart rate statistics (avg, min, max, time in each zone) for the last N seconds',
    {
      pairingCode: z.string().describe('The user\'s pairing code (e.g., tiger42)'),
      seconds: z.number().min(1).max(1800).default(60).describe('Number of seconds to calculate stats over (1-1800)')
    },
    async ({ pairingCode, seconds }) => {
      if (!isValidPairingCode(pairingCode)) {
        return {
          content: [{ type: 'text', text: 'Invalid pairing code format. Expected format: animal + 2 digits (e.g., tiger42)' }],
          isError: true
        };
      }

      const stats = getStats(pairingCode, seconds);

      if (!stats) {
        return {
          content: [{ type: 'text', text: `No heart rate data in the last ${seconds} seconds for ${pairingCode}.` }]
        };
      }

      // Format time in zone as readable string
      const zoneStr = Object.entries(stats.timeInZone)
        .filter(([_, count]) => count > 0)
        .map(([zone, count]) => `Z${zone}: ${count}s`)
        .join(', ');

      return {
        content: [{
          type: 'text',
          text: `Stats (last ${seconds}s): Avg ${stats.avg} BPM, Min ${stats.min}, Max ${stats.max}. Time in zones: ${zoneStr || 'none'}`
        }],
        structuredContent: {
          avg: stats.avg,
          min: stats.min,
          max: stats.max,
          count: stats.count,
          timeInZone: stats.timeInZone
        }
      };
    }
  );

  return server;
}

// Handle MCP requests
export async function handleMcpRequest(req: Request, res: Response) {
  const server = createMcpServer();

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
