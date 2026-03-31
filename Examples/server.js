/**
 * Servidor Node.js para recibir datos de MQL4
 *
 * Requisitos:
 * npm install express body-parser cors
 *
 * Ejecutar:
 * node server.js
 */

const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = 3000;

// Middleware
app.use(cors());                    // Permitir CORS para desarrollo
app.use(bodyParser.json());         // Parsear application/json
app.use(bodyParser.urlencoded({     // Parsear application/x-www-form-urlencoded
    extended: true
}));

// Log file para guardar datos recibidos
const LOG_FILE = path.join(__dirname, 'mt4_data.log');

// Función para guardar logs
function logData(data) {
    const timestamp = new Date().toISOString();
    const logEntry = `[${timestamp}] ${JSON.stringify(data)}\n`;

    fs.appendFile(LOG_FILE, logEntry, (err) => {
        if (err) console.error('Error guardando log:', err);
    });

    // También mostrar en consola
    console.log(`[${timestamp}] Datos recibidos:`, data);
}

// Endpoint principal para recibir datos de MQL4
app.post('/receive-data', (req, res) => {
    const data = req.body;

    console.log('========================================');
    console.log('NUEVA SOLICITUD DE MQL4 RECIBIDA');
    console.log('========================================');

    // Mostrar datos recibidos
    console.log('Símbolo:', data.symbol || 'N/A');
    console.log('Bid:', data.bid || 'N/A');
    console.log('Ask:', data.ask || 'N/A');
    console.log('Spread:', data.spread || 'N/A');
    console.log('Balance:', data.balance || 'N/A');
    console.log('Equity:', data.equity || 'N/A');
    console.log('Profit:', data.profit || 'N/A');
    console.log('Timestamp:', data.timestamp || 'N/A');
    console.log('Tipo de evento:', data.event_type || 'N/A');

    // Guardar en log
    logData(data);

    // Responder al EA
    res.json({
        success: true,
        message: 'Datos recibidos correctamente',
        received: {
            symbol: data.symbol,
            timestamp: data.timestamp,
            server_time: Math.floor(Date.now() / 1000)
        }
    });
});

// Endpoint para pruebas de conexión
app.post('/test', (req, res) => {
    console.log('Test de conexión recibido');
    res.json({
        success: true,
        message: 'Conexión exitosa',
        server_time: Math.floor(Date.now() / 1000)
    });
});

// Endpoint para obtener estadísticas
app.get('/stats', (req, res) => {
    fs.readFile(LOG_FILE, 'utf8', (err, data) => {
        if (err) {
            return res.json({
                total_requests: 0,
                error: 'No hay datos aún'
            });
        }

        const lines = data.trim().split('\n');
        const requests = lines.filter(line => line.length > 0);

        res.json({
            total_requests: requests.length,
            last_request: requests.length > 0 ? requests[requests.length - 1] : null
        });
    });
});

// Endpoint para ver logs
app.get('/logs', (req, res) => {
    fs.readFile(LOG_FILE, 'utf8', (err, data) => {
        if (err) {
            return res.json({
                logs: [],
                message: 'No hay logs disponibles'
            });
        }

        const lines = data.trim().split('\n').filter(line => line.length > 0);
        const logs = lines.slice(-100); // Últimos 100 logs

        res.json({
            total: lines.length,
            logs: logs
        });
    });
});

// Servir página de ejemplo (opcional)
app.get('/', (req, res) => {
    res.send(`
        <!DOCTYPE html>
        <html>
        <head>
            <title>MQL4 Web Receiver</title>
            <style>
                body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
                h1 { color: #333; }
                .section { background: #f5f5f5; padding: 15px; margin: 10px 0; border-radius: 5px; }
                code { background: #ddd; padding: 2px 5px; border-radius: 3px; }
            </style>
        </head>
        <body>
            <h1>🎯 MQL4 Web Receiver Server</h1>

            <div class="section">
                <h2>✅ Servidor funcionando</h2>
                <p>Puerto: ${PORT}</p>
                <p>Hora: ${new Date().toLocaleString()}</p>
            </div>

            <div class="section">
                <h2>📡 Endpoints disponibles:</h2>
                <ul>
                    <li><code>POST /receive-data</code> - Recibir datos de MQL4</li>
                    <li><code>POST /test</code> - Probar conexión</li>
                    <li><code>GET /stats</code> - Ver estadísticas</li>
                    <li><code>GET /logs</code> - Ver logs</li>
                </ul>
            </div>

            <div class="section">
                <h2>📝 Ejemplo de datos esperados:</h2>
                <pre>{
    "symbol": "EURUSD",
    "bid": "1.08500",
    "ask": "1.08510",
    "spread": "10",
    "balance": "10000.00",
    "equity": "10050.00",
    "profit": "50.00",
    "timestamp": "1712345678"
}</pre>
            </div>
        </body>
        </html>
    `);
});

// Iniciar servidor
app.listen(PORT, () => {
    console.log('╔════════════════════════════════════════╗');
    console.log('║   MQL4 Web Receiver Server Iniciado    ║');
    console.log('╚════════════════════════════════════════╝');
    console.log(`🚀 Servidor corriendo en http://localhost:${PORT}`);
    console.log(`📝 Logs guardados en: ${LOG_FILE}`);
    console.log(`⏰ Iniciado: ${new Date().toLocaleString()}`);
    console.log('\n✅ Listo para recibir datos de MQL4\n');
});
