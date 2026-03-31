/**
 * Servidor TCP + HTTP para comunicación bidireccional con MT4
 *
 * Este servidor:
 * 1. Escucha conexiones TCP de MT4 en el puerto 9000
 * 2. Sirve un dashboard web vía HTTP en el puerto 3000
 * 3. Permite enviar comandos a MT4 desde la web
 *
 * Uso:
 *   node tcp-server.js
 */

const net = require('net');
const express = require('express');
const cors = require('cors');
const path = require('path');

// Crear aplicación Express
const app = express();
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname))); // Servir archivos estáticos

// ============================================================================
// ALMACENAMIENTO DE DATOS
// ============================================================================

// Datos de MT4
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
    margin: null
};

// Comandos pendientes para enviar a MT4
let pendingCommands = [];

// Conexión socket activa
let mt4Socket = null;

// ============================================================================
// SERVIDOR TCP - Para conexión desde MT4
// ============================================================================

const tcpServer = net.createServer((socket) => {
    console.log('✅ MT4 conectado desde:', socket.remoteAddress + ':' + socket.remotePort);

    mt4Socket = socket;
    mt4Data.connected = true;

    // Enviar comandos pendientes inmediatamente al conectar
    if(pendingCommands.length > 0) {
        console.log('📤 Enviando comandos pendientes:', pendingCommands.length);
        pendingCommands.forEach(cmd => {
            socket.write(JSON.stringify(cmd) + '\n');
        });
        pendingCommands = [];
    }

    // Cuando MT4 envía datos
    socket.on('data', (data) => {
        try {
            // Procesar múltiples mensajes JSON separados por nueva línea
            const messages = data.toString().split('\n').filter(m => m.trim().length > 0);

            messages.forEach(msg => {
                try {
                    const json = JSON.parse(msg);
                    processMt4Message(json, socket);
                } catch(e) {
                    console.log('⚠️ Datos no-JSON:', msg);
                }
            });

        } catch(e) {
            console.log('⚠️ Error procesando datos:', e.message);
        }
    });

    // Cuando MT4 se desconecta
    socket.on('end', () => {
        console.log('❌ MT4 desconectado (end)');
        mt4Socket = null;
        mt4Data.connected = false;
    });

    socket.on('close', () => {
        console.log('❌ MT4 desconectado (close)');
        mt4Socket = null;
        mt4Data.connected = false;
    });

    // Cuando hay un error
    socket.on('error', (err) => {
        console.error('❌ Error en socket TCP:', err.message);
        mt4Socket = null;
        mt4Data.connected = false;
    });
});

// Manejar errores del servidor TCP
tcpServer.on('error', (err) => {
    console.error('❌ Error en servidor TCP:', err.message);
});

// ============================================================================
// PROCESAMIENTO DE MENSAJES DESDE MT4
// ============================================================================

function processMt4Message(json, socket) {
    console.log('📡 Recibido de MT4:', json);

    switch(json.type) {
        case 'market':
            // Actualizar datos de mercado
            mt4Data.symbol = json.symbol;
            mt4Data.bid = json.bid;
            mt4Data.ask = json.ask;
            mt4Data.spread = json.spread;
            mt4Data.digits = json.digits;
            mt4Data.balance = json.balance;
            mt4Data.equity = json.equity;
            mt4Data.profit = json.profit;
            mt4Data.margin = json.margin;
            mt4Data.lastUpdate = new Date().toISOString();
            break;

        case 'ping':
            // Responder al heartbeat
            socket.write('{"type":"pong"}\n');
            console.log('💓 Heartbeat respondido');
            break;

        default:
            console.log('⚠️ Tipo de mensaje no reconocido:', json.type);
    }
}

// ============================================================================
// ENDPOINTS HTTP - Para dashboard web
// ============================================================================

// GET /data - Obtener datos actuales de MT4
app.get('/data', (req, res) => {
    res.json(mt4Data);
});

// POST /command - Enviar comando a MT4
app.post('/command', (req, res) => {
    const { type, message } = req.body;

    if(!type) {
        return res.status(400).json({ success: false, error: 'type es requerido' });
    }

    const command = {
        type: type,
        message: message || '',
        timestamp: new Date().toISOString()
    };

    // Si MT4 está conectado, enviar inmediatamente
    if(mt4Socket && mt4Data.connected) {
        mt4Socket.write(JSON.stringify(command) + '\n');
        console.log('📤 Comando enviado a MT4:', command);
        return res.json({ success: true, sent: true });
    }

    // Si no está conectado, encolar para cuando se conecte
    pendingCommands.push(command);
    console.log('📝 Comando encolado (MT4 no conectado):', command);

    res.json({ success: true, sent: false, queued: true });
});

// GET /health - Health check
app.get('/health', (req, res) => {
    res.json({
        server: 'running',
        mt4_connected: mt4Data.connected,
        pending_commands: pendingCommands.length,
        uptime: process.uptime()
    });
});

// GET / - Servir dashboard
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'dashboard.html'));
});

// ============================================================================
// INICIAR SERVIDORES
// ============================================================================

const TCP_PORT = process.env.TCP_PORT || 8080;
const HTTP_PORT = process.env.HTTP_PORT || 3030;

// Iniciar servidor TCP
tcpServer.listen(TCP_PORT, '0.0.0.0', () => {
    console.log('╔═══════════════════════════════════════════════════════════╗');
    console.log('║         MT4 TCP Server Iniciado                          ║');
    console.log('╚═══════════════════════════════════════════════════════════╝');
    console.log(`🚀 Servidor TCP escuchando en puerto ${TCP_PORT}`);
    console.log(`   - MT4 debe conectarse a: tcp://localhost:${TCP_PORT}`);
    console.log('');
});

// Iniciar servidor HTTP
app.listen(HTTP_PORT, '0.0.0.0', () => {
    const isProduction = process.env.NODE_ENV === 'production';
    const hostUrl = isProduction ? process.env.HOST_URL || `http://localhost:${HTTP_PORT}` : `http://localhost:${HTTP_PORT}`;

    console.log(`🌐 Dashboard disponible en:`);
    console.log(`   - Local: http://localhost:${HTTP_PORT}`);
    if (isProduction) {
        console.log(`   - Production: ${hostUrl}`);
    }
    console.log('');
    console.log('✅ Servidor listo para recibir conexiones de MT4');
    console.log(`📡 MT4 debe conectarse a TCP puerto ${TCP_PORT}`);
    console.log('');
    console.log('Press Ctrl+C to stop');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
});

// Manejar shutdown gracioso
process.on('SIGINT', () => {
    console.log('\n\n🛑 Deteniendo servidor...');

    if(mt4Socket) {
        mt4Socket.end();
        console.log('🔌 Conexión MT4 cerrada');
    }

    tcpServer.close();
    console.log('✅ Servidor detenido');
    process.exit(0);
});
