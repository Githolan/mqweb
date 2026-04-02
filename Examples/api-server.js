/**
 * API Server for MT4 Communication
 *
 * HTTPS/REST API approach - works through Cloudflare Proxy
 *
 * Endpoints:
 *   POST /receive-data    - MT4 sends market data
 *   GET  /get-commands    - MT4 polls for pending commands
 *   GET  /data            - Dashboard gets current MT4 data
 *   POST /command         - Dashboard sends command to MT4
 *   GET  /health          - Health check
 *   GET  /                - Dashboard
 */

const express = require('express');
const cors = require('cors');
const path = require('path');

const app = express();

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname)));

// ============================================================================
// DATA STORAGE
// ============================================================================

// MT4 Data
const mt4Data = {
    connected: false,
    lastUpdate: null,
    symbol: null,
    bid: null,
    ask: null,
    spread: null,
    digits: null,
    balance: null,
    equity: null,
    profit: null,
    margin: null,
    time: null
};

// Pending commands for MT4 (queue)
const pendingCommands = [];

// Connection tracking
let lastMqttPing = null;

// ============================================================================
// MT4 ENDPOINTS
// ============================================================================

/**
 * GET /receive-data
 * MT4 sends market data via query parameters (for wininet.dll compatibility)
 */
app.get('/receive-data', (req, res) => {
    const data = req.query;

    console.log('📊 Data from MT4 (GET):', data);
    processMarketData(data);

    res.json({ success: true, received: true });
});

/**
 * POST /receive-data
 * MT4 sends market data here (JSON body)
 */
app.post('/receive-data', (req, res) => {
    const data = req.body;

    console.log('📊 Data from MT4 (POST):', data);
    processMarketData(data);

    res.json({ success: true, received: true });
});

/**
 * Process market data from either GET or POST
 */
function processMarketData(data) {

    // Update stored data
    if (data.type === 'market') {
        mt4Data.symbol = data.symbol;
        mt4Data.bid = data.bid;
        mt4Data.ask = data.ask;
        mt4Data.spread = data.spread;
        mt4Data.digits = data.digits;
        mt4Data.balance = data.balance;
        mt4Data.equity = data.equity;
        mt4Data.profit = data.profit;
        mt4Data.margin = data.margin;
        mt4Data.time = data.time;
        mt4Data.lastUpdate = new Date().toISOString();
    }

    // Mark as connected
    mt4Data.connected = true;
    lastMqttPing = Date.now();
}

/**
 * GET /get-commands
 * MT4 polls for pending commands
 */
app.get('/get-commands', (req, res) => {
    // Mark as connected
    mt4Data.connected = true;
    lastMqttPing = Date.now();

    if (pendingCommands.length === 0) {
        res.json({ commands: [] });
        return;
    }

    // Get all pending commands and clear queue
    const commands = [...pendingCommands];
    pendingCommands.length = 0;

    console.log('📤 Sending commands to MT4:', commands);

    res.json({ commands: commands });
});

/**
 * POST /mt4-status
 * MT4 sends status/heartbeat
 */
app.post('/mt4-status', (req, res) => {
    mt4Data.connected = true;
    lastMqttPing = Date.now();
    mt4Data.lastUpdate = new Date().toISOString();

    res.json({ success: true });
});

// ============================================================================
// DASHBOARD ENDPOINTS
// ============================================================================

/**
 * GET /data
 * Dashboard gets current MT4 data
 */
app.get('/data', (req, res) => {
    // Check if MT4 is still connected (timeout after 30 seconds)
    if (lastMqttPing && (Date.now() - lastMqttPing > 30000)) {
        mt4Data.connected = false;
    }

    res.json(mt4Data);
});

/**
 * POST /command
 * Dashboard sends command to MT4
 */
app.post('/command', (req, res) => {
    const { type, message } = req.body;

    if (!type) {
        return res.status(400).json({ success: false, error: 'type is required' });
    }

    const command = {
        type: type,
        message: message || '',
        timestamp: new Date().toISOString()
    };

    pendingCommands.push(command);

    console.log('📝 Command queued:', command);

    res.json({
        success: true,
        queued: true,
        pendingCount: pendingCommands.length
    });
});

/**
 * GET /health
 * Health check endpoint
 */
app.get('/health', (req, res) => {
    // Check MT4 connection status
    if (lastMqttPing && (Date.now() - lastMqttPing > 30000)) {
        mt4Data.connected = false;
    }

    res.json({
        server: 'running',
        mt4_connected: mt4Data.connected,
        pending_commands: pendingCommands.length,
        uptime: process.uptime()
    });
});

/**
 * GET /
 * Serve dashboard
 */
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'api-dashboard.html'));
});

// ============================================================================
// START SERVER
// ============================================================================

const PORT = process.env.HTTP_PORT || process.env.PORT || 3030;

app.listen(PORT, '0.0.0.0', () => {
    console.log('╔═══════════════════════════════════════════════════════════╗');
    console.log('║         MQL4-WEB API Server Started                       ║');
    console.log('╚═══════════════════════════════════════════════════════════╝');
    console.log(`🌐 Server listening on port ${PORT}`);
    console.log(`   - Dashboard:  http://localhost:${PORT}`);
    console.log(`   - Health:     http://localhost:${PORT}/health`);
    console.log('');
    console.log('📡 MT4 API Endpoints:');
    console.log(`   - POST /receive-data  - Send market data`);
    console.log(`   - GET  /get-commands  - Poll for commands`);
    console.log('');
    console.log('✅ Ready for connections');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
});

// Graceful shutdown
process.on('SIGINT', () => {
    console.log('\n\n🛑 Server stopping...');
    process.exit(0);
});
