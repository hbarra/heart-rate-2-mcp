import express from 'express';
import cors from 'cors';
import { apiRouter } from './api';
import { handleMcpRequest } from './mcp';

const app = express();

// Middleware
app.use(express.json());
app.use(cors({
  origin: '*',
  exposedHeaders: ['Mcp-Session-Id']
}));

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// REST API routes
app.use('/api', apiRouter);

// MCP endpoint
app.post('/mcp', handleMcpRequest);

// Start server
const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  console.log(`Heart Rate 2 MCP server running on port ${PORT}`);
  console.log(`- REST API: http://localhost:${PORT}/api/hr`);
  console.log(`- MCP endpoint: http://localhost:${PORT}/mcp`);
});
