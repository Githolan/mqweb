//+------------------------------------------------------------------+
//|                                    TcpBidirectionalEA.mq4        |
//|                        Expert Advisor con comunicación TCP        |
//|                        Usa ws2_32.dll para bypass del sandbox     |
//+------------------------------------------------------------------+
#property copyright "MQL4 TCP Communication"
#property link      "https://github.com/vivazzi/mql_requests"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Parámetros de entrada                                            |
//+------------------------------------------------------------------+
input string   SERVER_HOST        = "127.0.0.1";      // Dirección del servidor
input int      SERVER_PORT        = 8080;             // Puerto TCP
input int      RECONNECT_SECONDS  = 10;               // Segundos entre reintentos de conexión
input int      SEND_INTERVAL      = 3;                // Segundos entre envíos de datos
input bool     DEBUG_MODE         = true;             // Mostrar mensajes de debug

//+------------------------------------------------------------------+
//| Importación de funciones WinSock                                  |
//+------------------------------------------------------------------+
#import "ws2_32.dll"
    int WSAStartup(ushort wVersionRequested, int& lpWSAData[]);
    int WSACleanup();
    int socket(int af, int type, int protocol);
    int connect(int s, uchar& name[], int namelen);
    int send(int s, uchar& buf[], int len, int flags);
    int recv(int s, uchar& buf[], int len, int flags);
    int closesocket(int s);
    int WSAGetLastError();
    ushort htons(ushort hostshort);
#import

//+------------------------------------------------------------------+
//| Constantes WinSock                                               |
//+------------------------------------------------------------------+
#define AF_INET         2
#define SOCK_STREAM     1
#define IPPROTO_TCP     6
#define INVALID_SOCKET  -1

//+------------------------------------------------------------------+
//| Variables globales                                               |
//+------------------------------------------------------------------+
int      g_socket              = INVALID_SOCKET;
bool     g_connected           = false;
datetime g_lastConnectAttempt  = 0;
datetime g_lastSendTime        = 0;
int      g_heartbeatSeconds    = 30;
datetime g_lastHeartbeat       = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("========================================");
    Print("TcpBidirectionalEA iniciado");
    Print("Servidor: ", SERVER_HOST, ":", SERVER_PORT);
    Print("========================================");

    if(!ConnectToServer())
    {
        Print("No se pudo conectar al servidor. Reintentara automaticamente...");
        g_lastConnectAttempt = TimeCurrent();
    }
    else
    {
        SendMarketData();
    }

    EventSetMillisecondTimer(1000);
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    EventKillTimer();
    Disconnect();
    Print("TcpBidirectionalEA detenido. Razon: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!g_connected)
    {
        TryReconnect();
        return;
    }

    if(TimeCurrent() - g_lastSendTime >= SEND_INTERVAL)
    {
        SendMarketData();
        g_lastSendTime = TimeCurrent();
    }

    CheckForCommands();
}

//+------------------------------------------------------------------+
//| Timer event handler                                              |
//+------------------------------------------------------------------+
void OnTimer()
{
    if(!g_connected)
    {
        TryReconnect();
    }
    else
    {
        if(TimeCurrent() - g_lastHeartbeat >= g_heartbeatSeconds)
        {
            SendHeartbeat();
            g_lastHeartbeat = TimeCurrent();
        }
        CheckForCommands();
    }
}

//+------------------------------------------------------------------+
//| Parsear IP a unsigned long (manual - inet_addr no funciona bien)  |
//+------------------------------------------------------------------+
ulong ParseIpToLong(string ip)
{
    string parts[];
    StringSplit(ip, '.', parts);

    if(ArraySize(parts) != 4)
        return 0;

    int p1 = (int)StringToInteger(parts[0]);
    int p2 = (int)StringToInteger(parts[1]);
    int p3 = (int)StringToInteger(parts[2]);
    int p4 = (int)StringToInteger(parts[3]);

    // Para 127.0.0.1: p4*256^3 + p3*256^2 + p2*256 + p1
    // = 1*16777216 + 0*65536 + 0*256 + 127
    // = 16777216 + 127 = 16777343 (0x0100007F)
    return (ulong)p4 * 16777216 + (ulong)p3 * 65536 + (ulong)p2 * 256 + (ulong)p1;
}

//+------------------------------------------------------------------+
//| Conectar al servidor TCP                                         |
//+------------------------------------------------------------------+
bool ConnectToServer()
{
    if(DEBUG_MODE)
        Print("Intentando conectar a ", SERVER_HOST, ":", SERVER_PORT);

    // 1. Inicializar Winsock
    int wsaData[100];
    ArrayInitialize(wsaData, 0);

    int result = WSAStartup(0x0202, wsaData);
    if(result != 0)
    {
        Print("Error WSAStartup failed. Codigo: ", result);
        return false;
    }

    if(DEBUG_MODE)
        Print("Winsock inicializado correctamente");

    // 2. Crear socket
    g_socket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if(g_socket == INVALID_SOCKET)
    {
        int err = WSAGetLastError();
        Print("Error socket() failed. Codigo: ", err);
        WSACleanup();
        return false;
    }

    if(DEBUG_MODE)
        Print("Socket creado: ", g_socket);

    // 3. Preparar estructura sockaddr_in (16 bytes)
    // Usamos uchar array para control exacto de cada byte
    uchar serverAddr[16];
    ArrayInitialize(serverAddr, 0);

    // sockaddr_in estructura:
    // Offset 0-1: sin_family (2 bytes, little-endian)
    serverAddr[0] = AF_INET;         // 2
    serverAddr[1] = 0;

    // Offset 2-3: sin_port (2 bytes, NETWORK byte order = big-endian)
    ushort portNet = htons((ushort)SERVER_PORT);
    serverAddr[2] = (uchar)(portNet & 0xFF);        // Byte bajo de htons(8080) = 0x1F
    serverAddr[3] = (uchar)(portNet >> 8);          // Byte alto de htons(8080) = 0x90

    // Offset 4-7: sin_addr (4 bytes, NETWORK byte order = big-endian)
    ulong ipLong = ParseIpToLong(SERVER_HOST);
    serverAddr[4] = (uchar)(ipLong & 0xFF);         // 127 = 0x7F
    serverAddr[5] = (uchar)((ipLong >> 8) & 0xFF);  // 0
    serverAddr[6] = (uchar)((ipLong >> 16) & 0xFF); // 0
    serverAddr[7] = (uchar)((ipLong >> 24) & 0xFF); // 1

    // Offset 8-15: sin_zero (8 bytes de padding, ya en 0)

    if(DEBUG_MODE)
    {
        Print("sockaddr_in bytes:");
        Print("  [0-1] family: ", serverAddr[0], ".", serverAddr[1]);
        Print("  [2-3] port: ", serverAddr[2], ".", serverAddr[3], " (htons 8080)");
        Print("  [4-7] IP: ", serverAddr[4], ".", serverAddr[5], ".", serverAddr[6], ".", serverAddr[7]);
        Print("  ParseIpToLong result: ", ipLong);
    }

    // 4. Conectar
    result = connect(g_socket, serverAddr, 16);
    if(result != 0)
    {
        int err = WSAGetLastError();
        if(DEBUG_MODE)
            Print("Error connect() failed. Codigo: ", err, " - ", GetWsaErrorString(err));

        closesocket(g_socket);
        WSACleanup();
        g_socket = INVALID_SOCKET;
        return false;
    }

    g_connected = true;
    Print("Conectado al servidor TCP ", SERVER_HOST, ":", SERVER_PORT);
    return true;
}

//+------------------------------------------------------------------+
//| Obtener descripción de error WSA                                  |
//+------------------------------------------------------------------+
string GetWsaErrorString(int err)
{
    switch(err)
    {
        case 10047: return "WSAEAFNOSUPPORT - Address family not supported";
        case 10048: return "WSAEADDRINUSE - Address already in use";
        case 10049: return "WSAEADDRNOTAVAIL - Cannot assign requested address";
        case 10050: return "WSAENETDOWN - Network is down";
        case 10051: return "WSAENETUNREACH - Network is unreachable";
        case 10052: return "WSAENETRESET - Network dropped connection on reset";
        case 10053: return "WSAECONNABORTED - Software caused connection abort";
        case 10054: return "WSAECONNRESET - Connection reset by peer";
        case 10055: return "WSAENOBUFS - No buffer space available";
        case 10056: return "WSAEISCONN - Socket is already connected";
        case 10057: return "WSAENOTCONN - Socket is not connected";
        case 10058: return "WSAESHUTDOWN - Cannot send after socket shutdown";
        case 10059: return "WSAETOOMANYREFS - Too many references";
        case 10060: return "WSAETIMEDOUT - Connection timed out";
        case 10061: return "WSAECONNREFUSED - Connection refused (server not listening?)";
        case 10062: return "WSAELOOP - Translation name loopback";
        case 10063: return "WSAENAMETOOLONG - Name too long";
        case 10064: return "WSAEHOSTDOWN - Host is down";
        case 10065: return "WSAEHOSTUNREACH - No route to host";
        default: return "Unknown error";
    }
}

//+------------------------------------------------------------------+
//| Desconectar del servidor                                         |
//+------------------------------------------------------------------+
void Disconnect()
{
    if(g_socket != INVALID_SOCKET)
    {
        closesocket(g_socket);
        g_socket = INVALID_SOCKET;
    }
    WSACleanup();
    g_connected = false;

    if(DEBUG_MODE)
        Print("Desconectado del servidor");
}

//+------------------------------------------------------------------+
//| Intentar reconectar                                              |
//+------------------------------------------------------------------+
void TryReconnect()
{
    if(TimeCurrent() - g_lastConnectAttempt < RECONNECT_SECONDS)
        return;

    if(DEBUG_MODE)
        Print("Reintentando conexion...");

    Disconnect();
    ConnectToServer();

    g_lastConnectAttempt = TimeCurrent();

    if(g_connected)
    {
        SendMarketData();
    }
}

//+------------------------------------------------------------------+
//| Enviar datos de mercado al servidor                              |
//+------------------------------------------------------------------+
void SendMarketData()
{
    string symbol = _Symbol;
    double bid = MarketInfo(symbol, MODE_BID);
    double ask = MarketInfo(symbol, MODE_ASK);
    int spread = (int)MarketInfo(symbol, MODE_SPREAD);
    int digits = (int)MarketInfo(symbol, MODE_DIGITS);

    double balance = AccountBalance();
    double equity = AccountEquity();
    double profit = AccountProfit();
    double margin = AccountMargin();

    string json = "{";
    json += "\"type\":\"market\",";
    json += "\"symbol\":\"" + symbol + "\",";
    json += "\"bid\":\"" + DoubleToString(bid, digits) + "\",";
    json += "\"ask\":\"" + DoubleToString(ask, digits) + "\",";
    json += "\"spread\":" + IntegerToString(spread) + ",";
    json += "\"digits\":" + IntegerToString(digits) + ",";
    json += "\"balance\":\"" + DoubleToString(balance, 2) + "\",";
    json += "\"equity\":\"" + DoubleToString(equity, 2) + "\",";
    json += "\"profit\":\"" + DoubleToString(profit, 2) + "\",";
    json += "\"margin\":\"" + DoubleToString(margin, 2) + "\",";
    json += "\"time\":" + IntegerToString(TimeCurrent());
    json += "}\n";

    SendData(json);
}

//+------------------------------------------------------------------+
//| Enviar heartbeat                                                 |
//+------------------------------------------------------------------+
void SendHeartbeat()
{
    SendData("{\"type\":\"ping\",\"time\":" + IntegerToString(TimeCurrent()) + "}\n");
}

//+------------------------------------------------------------------+
//| Enviar datos al servidor                                         |
//+------------------------------------------------------------------+
void SendData(string data)
{
    if(!g_connected || g_socket == INVALID_SOCKET)
        return;

    uchar buffer[];
    int len = StringLen(data);
    ArrayResize(buffer, len);

    for(int i = 0; i < len; i++)
    {
        buffer[i] = (uchar)StringGetCharacter(data, i);
    }

    int sent = send(g_socket, buffer, len, 0);

    if(sent < 0)
    {
        int err = WSAGetLastError();
        Print("Error send() failed. Codigo: ", err);
        g_connected = false;
    }
    else if(DEBUG_MODE && StringFind(data, "\"type\":\"ping\"") < 0)
    {
        Print("Datos enviados: ", StringSubstr(data, 0, MathMin(50, StringLen(data))));
    }
}

//+------------------------------------------------------------------+
//| Verificar si hay comandos pendientes del servidor                |
//+------------------------------------------------------------------+
void CheckForCommands()
{
    if(!g_connected || g_socket == INVALID_SOCKET)
        return;

    uchar buffer[4096];
    ArrayInitialize(buffer, 0);

    int received = recv(g_socket, buffer, 4095, 0);

    if(received > 0)
    {
        string response = "";
        for(int i = 0; i < received; i++)
        {
            response += CharToString((uchar)buffer[i]);
        }

        if(DEBUG_MODE)
            Print("Datos recibidos: ", StringSubstr(response, 0, MathMin(100, StringLen(response))));

        ProcessCommand(response);
    }
    else if(received < 0)
    {
        int err = WSAGetLastError();
        if(err != 10035)  // WSAEWOULDBLOCK
        {
            Print("Error recv() failed. Codigo: ", err);
            g_connected = false;
        }
    }
}

//+------------------------------------------------------------------+
//| Procesar comando recibido del servidor                           |
//+------------------------------------------------------------------+
void ProcessCommand(string data)
{
    int pos = 0;
    string command;

    while((pos = StringFind(data, "\n")) >= 0)
    {
        command = StringSubstr(data, 0, pos);
        data = StringSubstr(data, pos + 1);
        ParseAndExecuteCommand(command);
    }

    if(data != "")
        ParseAndExecuteCommand(data);
}

//+------------------------------------------------------------------+
//| Parsear y ejecutar un comando                                    |
//+------------------------------------------------------------------+
void ParseAndExecuteCommand(string json)
{
    if(StringFind(json, "\"type\":\"alert\"") >= 0)
    {
        string msg = ExtractJsonValue(json, "message");
        if(msg != "")
        {
            Alert("Mensaje del servidor: ", msg);
            Print("Alerta mostrada: ", msg);
        }
    }

    if(StringFind(json, "\"type\":\"pong\"") >= 0)
    {
        if(DEBUG_MODE)
            Print("Heartbeat recibido");
    }

    if(StringFind(json, "\"type\":\"log\"") >= 0)
    {
        string msg = ExtractJsonValue(json, "message");
        if(msg != "")
            Print("Log del servidor: ", msg);
    }
}

//+------------------------------------------------------------------+
//| Extraer valor de un JSON simple                                  |
//+------------------------------------------------------------------+
string ExtractJsonValue(string json, string key)
{
    string search = "\"" + key + "\":\"";
    int start = StringFind(json, search);

    if(start < 0)
    {
        search = "\"" + key + "\":";
        start = StringFind(json, search);
        if(start >= 0)
        {
            start += StringLen(search);
            int end = StringFind(json, ",", start);
            if(end < 0) end = StringFind(json, "}", start);
            if(end > start)
                return StringSubstr(json, start, end - start);
        }
        return "";
    }

    start += StringLen(search);
    int end = StringFind(json, "\"", start);

    if(end > start)
        return StringSubstr(json, start, end - start);

    return "";
}
//+------------------------------------------------------------------+
