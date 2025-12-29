"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const api_1 = require("./api");
const mcp_1 = require("./mcp");
const app = (0, express_1.default)();
// Middleware
app.use(express_1.default.json());
app.use((0, cors_1.default)({
    origin: '*',
    exposedHeaders: ['Mcp-Session-Id']
}));
// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});
// REST API routes
app.use('/api', api_1.apiRouter);
// MCP endpoint
app.post('/mcp', mcp_1.handleMcpRequest);
// Start server
const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
    console.log(`Heart Rate 2 MCP server running on port ${PORT}`);
    console.log(`- REST API: http://localhost:${PORT}/api/hr`);
    console.log(`- MCP endpoint: http://localhost:${PORT}/mcp`);
});
