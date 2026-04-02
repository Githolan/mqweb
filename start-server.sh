#!/bin/sh
# MQL4-WEB Server Starter
# Selects server based on SERVER_MODE environment variable

echo "========================================"
echo "  MQL4-WEB Server Starter"
echo "========================================"
echo "SERVER_MODE: ${SERVER_MODE:-api}"
echo "HTTP_PORT: ${HTTP_PORT:-3030}"
echo "TCP_PORT: ${TCP_PORT:-8080}"
echo "========================================"

case "${SERVER_MODE}" in
    "tcp")
        echo "Starting TCP Bidirectional Server..."
        exec node Examples/tcp-server.js
        ;;
    "api")
        echo "Starting API Polling Server..."
        exec node Examples/api-server.js
        ;;
    *)
        echo "Unknown SERVER_MODE: ${SERVER_MODE}"
        echo "Valid options: api (default), tcp"
        echo "Defaulting to API server..."
        exec node Examples/api-server.js
        ;;
esac
