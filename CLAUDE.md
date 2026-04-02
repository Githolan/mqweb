# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MQL4-WEB is a communication system between MetaTrader 4 Expert Advisors and web services. It provides three approaches to bypass MQL4's sandbox restrictions:

1. **TCP Bidirectional** (Recommended for local/dev) - Uses WinSock (ws2_32.dll) for direct TCP sockets, enabling full bidirectional communication without "trusted websites" configuration
2. **API Polling Bidirectional** (Recommended for production/Cloudflare) - Uses native WebRequest with HTTP polling for bidirectional communication through any proxy/CDN
3. **HTTP Unidirectional** - Uses WinINET (wininet.dll) via the vivazzi/mql_requests library for HTTP requests from EA to web

## Commands

```powershell
# Server management (recommended)
.\Scripts\dev.ps1 start    # Start TCP server + dashboard
.\Scripts\dev.ps1 stop     # Stop all servers
.\Scripts\dev.ps1 status   # Check server status
.\Scripts\dev.ps1 restart  # Restart servers
.\Scripts\dev.ps1 logs     # View recent logs
.\Scripts\dev.ps1 install  # Install dependencies

# Alternative: direct npm scripts
npm run start:tcp          # Start TCP server (Examples/tcp-server.js)
npm start                  # Start HTTP-only server (Examples/server.js)

# API Polling server (for production/Cloudflare)
node Examples/api-server.js   # Start API server (port 3030)
```

## Ports

| Service | Port | URL |
|---------|------|-----|
| TCP Server | 8080 | tcp://localhost:8080 |
| HTTP Dashboard | 3030 | http://localhost:3030 |

## Architecture

### Option 1: TCP Bidirectional (Local/Dev)
```
┌─────────────────┐                ┌─────────────────┐                ┌─────────────┐
│  MT4 Expert     │                │   Node.js       │                │    Web      │
│  Advisor        │                │   Server        │                │  Dashboard  │
├─────────────────┤                ├─────────────────┤                ├─────────────┤
│ ws2_32.dll      │ ─── TCP ────── │ tcp-server.js   │ ─── HTTP ──── │ dashboard.  │
│ (WinSock)       │    8080        │ (Express+net)   │    3030       │ html        │
└─────────────────┘                └─────────────────┘                └─────────────┘
```

### Option 2: API Polling Bidirectional (Production/Cloudflare)
```
┌─────────────────┐                ┌─────────────────┐                ┌─────────────┐
│  MT4 Expert     │                │   Node.js       │                │    Web      │
│  Advisor        │                │   Server        │                │  Dashboard  │
├─────────────────┤                ├─────────────────┤                ├─────────────┤
│ WebRequest      │ ─── HTTP ──── │ api-server.js   │ ─── HTTP ──── │ api-        │
│ (native)        │    3030        │ (Express)       │    3030       │ dashboard   │
└─────────────────┘                └─────────────────┘                └─────────────┘
      ↑                                    │
      └──────── Poll /get-commands ────────┘
```

### TCP Communication Flow
- MT4 EA connects via WinSock to Node.js TCP server (port 8080)
- EA sends market data as JSON every 3 seconds
- Server can push commands to EA (alerts, logs)
- HTTP dashboard polls `/data` endpoint and sends commands via `/command`

### API Polling Communication Flow
- MT4 EA sends market data via POST /receive-data
- MT4 EA polls GET /get-commands every 3 seconds for pending commands
- Works through Cloudflare, proxies, and HTTPS without "trusted websites" config

### Key Components

| File | Purpose |
|------|---------|
| `Examples/TcpBidirectionalEA.mq4` | MT4 EA using ws2_32.dll for TCP sockets (bidirectional) |
| `Examples/tcp-server.js` | Combined TCP + HTTP server for TCP approach |
| `Examples/ApiBidirectionalEA.mq4` | MT4 EA using native WebRequest with polling (bidirectional) |
| `Examples/api-server.js` | HTTP-only server with polling support for API approach |
| `Examples/api-dashboard.html` | Web UI for API approach |
| `Examples/dashboard.html` | Web UI for TCP approach |
| `Examples/WebSenderEA.mq4` | EA using mql_requests for HTTP (unidirectional) |
| `Examples/server.js` | HTTP-only server for mql_requests |
| `Scripts/dev.ps1` | PowerShell server management script |

## Message Protocol

### MT4 → Server (JSON)
```json
{"type":"market","symbol":"EURUSD","bid":"1.0850","ask":"1.0851","spread":10,"balance":"10000.00","equity":"10050.00","profit":"50.00","margin":"500.00","time":1234567890}
{"type":"ping","time":1234567890}
```

### Server → MT4 (JSON)
```json
{"type":"alert","message":"Hello from web","timestamp":"2024-01-01T00:00:00.000Z"}
{"type":"pong"}
{"type":"log","message":"Server message"}
```

## Configuration

### EA Parameters (TcpBidirectionalEA.mq4)
- `SERVER_HOST`: TCP server address (default: "127.0.0.1")
- `SERVER_PORT`: TCP port (default: 8080)
- `RECONNECT_SECONDS`: Reconnection interval in seconds (default: 10)
- `SEND_INTERVAL`: Data send interval in seconds (default: 3)
- `DEBUG_MODE`: Enable debug logs (default: true)

### EA Parameters (ApiBidirectionalEA.mq4)
- `SERVER_HOST`: Server host or domain (default: "127.0.0.1")
- `SERVER_PORT`: Server port (default: 3030, use 443 for HTTPS)
- `USE_HTTPS`: Use HTTPS protocol (default: false)
- `SEND_INTERVAL`: Data send interval in seconds (default: 3)
- `POLL_INTERVAL`: Command poll interval in seconds (default: 3)
- `DEBUG_MODE`: Enable debug logs (default: true)

## MT4 Requirements

- Enable DLL imports: Tools → Options → Expert Advisors → "Allow DLL imports" (TCP approach only)
- Windows only for TCP approach (ws2_32.dll is Windows-native)
- Compile .mq4 files in MetaEditor (F7 in MT4)

## Troubleshooting

| Error | Solution |
|-------|----------|
| "DLL function call failed not allowed" | Tools → Options → Expert Advisors → ✅ "Allow DLL imports" |
| "Connection refused" (WSA error 10061) | Start TCP server first: `.\Scripts\dev.ps1 start` |
| "Connection timed out" (WSA error 10060) | Check firewall or server address/port |
| Port already in use | Run `.\Scripts\dev.ps1 stop` then `start` |
| EA not receiving commands | Check EA logs for "Datos recibidos" in debug mode |

## API Endpoints

### TCP Server (tcp-server.js)
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/` | GET | Serve dashboard |
| `/data` | GET | Get current MT4 data |
| `/command` | POST | Send command to MT4 (`{"type":"alert","message":"..."}`) |
| `/health` | GET | Server health check |

### API Server (api-server.js) - Polling Approach
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/` | GET | Serve api-dashboard |
| `/receive-data` | POST/GET | MT4 sends market data |
| `/get-commands` | GET | MT4 polls for pending commands |
| `/data` | GET | Dashboard gets current MT4 data |
| `/command` | POST | Dashboard queues command for MT4 |
| `/health` | GET | Server health check |

### HTTP Server (server.js) - Unidirectional
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/receive-data` | POST | HTTP endpoint for mql_requests |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SERVER_MODE` | api | Server type: `api` (recommended) or `tcp` |
| `HTTP_PORT` | 3030 | HTTP API/dashboard port |
| `TCP_PORT` | 8080 | TCP socket port (TCP mode only) |
| `NODE_ENV` | development | Set to `production` for deployment |

## Docker Deployment

### API Mode (Recommended for Production)
```bash
# Build
docker build -t mql4-web .

# Run API server (works through Cloudflare/proxies)
docker run -d -p 3030:3030 -e SERVER_MODE=api mql4-web

# Or use docker-compose
docker-compose up -d
```

### TCP Mode (Local Development)
```bash
# Run TCP server (requires direct socket access)
docker run -d -p 8080:8080 -p 3030:3030 -e SERVER_MODE=tcp mql4-web
```

### Coolify Deployment
1. Set `SERVER_MODE=api` in environment variables
2. Configure domain with HTTPS (Cloudflare tunnel recommended)
3. Update EA `SERVER_HOST` to your domain
4. Set `USE_HTTPS=true` and `SERVER_PORT=443` in EA

## Testing

```bash
# Test API server locally
node Scripts/test-api.js
```
