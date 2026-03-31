# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MQL4-WEB is a communication system between MetaTrader 4 Expert Advisors and web services. It provides two approaches to bypass MQL4's sandbox restrictions:

1. **TCP Bidirectional** (Recommended) - Uses WinSock (ws2_32.dll) for direct TCP sockets, enabling full bidirectional communication without "trusted websites" configuration
2. **HTTP Unidirectional** - Uses WinINET (wininet.dll) via the vivazzi/mql_requests library for HTTP requests from EA to web

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
npm run start:tcp          # Start TCP server directly
npm start                  # Start HTTP-only server (port 3000)
```

## Ports

| Service | Port | URL |
|---------|------|-----|
| TCP Server | 8080 | tcp://localhost:8080 |
| HTTP Dashboard | 3030 | http://localhost:3030 |

## Architecture

```
┌─────────────────┐                ┌─────────────────┐                ┌─────────────┐
│  MT4 Expert     │                │   Node.js       │                │    Web      │
│  Advisor        │                │   Server        │                │  Dashboard  │
├─────────────────┤                ├─────────────────┤                ├─────────────┤
│ ws2_32.dll      │ ─── TCP ────── │ tcp-server.js   │ ─── HTTP ──── │ dashboard.  │
│ (WinSock)       │    8080        │ (Express+net)   │    3030       │ html        │
└─────────────────┘                └─────────────────┘                └─────────────┘
```

### TCP Communication Flow
- MT4 EA connects via WinSock to Node.js TCP server (port 8080)
- EA sends market data as JSON every 3 seconds
- Server can push commands to EA (alerts, logs)
- HTTP dashboard polls `/data` endpoint and sends commands via `/command`

### Key Components

| File | Purpose |
|------|---------|
| `Examples/TcpBidirectionalEA.mq4` | MT4 EA using ws2_32.dll for TCP sockets |
| `Examples/tcp-server.js` | Combined TCP + HTTP server |
| `Examples/dashboard.html` | Web UI for monitoring and sending commands |
| `Examples/WebSenderEA.mq4` | EA using mql_requests for HTTP (unidirectional) |
| `Examples/server.js` | HTTP-only server for mql_requests |

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
- `RECONNECT_SECONDS`: Reconnection interval (default: 10)
- `SEND_INTERVAL`: Data send interval in seconds (default: 3)
- `DEBUG_MODE`: Enable debug logs (default: true)

## MT4 Requirements

- Enable DLL imports: Tools → Options → Expert Advisors → "Allow DLL imports"
- Windows only (ws2_32.dll is Windows-native)
- Compile .mq4 files in MetaEditor (F4 in MT4)

## API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/` | GET | Serve dashboard |
| `/data` | GET | Get current MT4 data |
| `/command` | POST | Send command to MT4 (`{"type":"alert","message":"..."}`) |
| `/health` | GET | Server health check |
| `/receive-data` | POST | HTTP endpoint for mql_requests (unidirectional) |
