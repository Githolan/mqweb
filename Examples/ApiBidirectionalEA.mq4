//+------------------------------------------------------------------+
//|                                    ApiBidirectionalEA.mq4        |
//|                        Expert Advisor con comunicación HTTP      |
//|                        Usa WebRequest nativo de MQL4             |
//+------------------------------------------------------------------+
#property copyright "MQL4 API Communication"
#property link      "https://github.com/holan/MQL4-WEB"
#property version   "2.00"
#property strict

//+------------------------------------------------------------------+
//| Parámetros de entrada                                            |
//+------------------------------------------------------------------+
input string   SERVER_HOST        = "127.0.0.1";      // Server host or domain
input int      SERVER_PORT        = 3030;             // Server port (443 for HTTPS)
input bool     USE_HTTPS          = false;            // Use HTTPS (true for production)
input int      SEND_INTERVAL      = 3;                // Seconds between data sends
input int      POLL_INTERVAL      = 3;                // Seconds between command polls
input bool     DEBUG_MODE         = true;             // Show debug messages

//+------------------------------------------------------------------+
//| Variables globales                                               |
//+------------------------------------------------------------------+
datetime g_lastSendTime        = 0;
datetime g_lastPollTime        = 0;
bool     g_initialized         = false;
string   g_baseUrl             = "";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("========================================");
    Print("ApiBidirectionalEA v2.0 (WebRequest)");
    Print("Server: ", SERVER_HOST, ":", SERVER_PORT);
    Print("HTTPS: ", USE_HTTPS ? "Si" : "No");
    Print("========================================");

    // Build base URL
    if(USE_HTTPS)
        g_baseUrl = "https://" + SERVER_HOST + ":" + IntegerToString(SERVER_PORT);
    else
        g_baseUrl = "http://" + SERVER_HOST + ":" + IntegerToString(SERVER_PORT);

    Print("Base URL: ", g_baseUrl);

    // Test connection
    if(DEBUG_MODE)
    {
        Print("Testing HTTP connection...");
        string testResponse = HttpGet("/health");
        if(StringLen(testResponse) > 0)
        {
            Print("✅ HTTP test successful");
            Print("Response: ", StringSubstr(testResponse, 0, MathMin(100, StringLen(testResponse))));
        }
        else
            Print("❌ HTTP test failed");
    }

    g_initialized = true;

    // Send initial data
    SendMarketData();

    // Start timer
    EventSetMillisecondTimer(1000);

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    EventKillTimer();
    Print("ApiBidirectionalEA detenido. Razon: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!g_initialized)
        return;

    // Send market data periodically
    if(TimeCurrent() - g_lastSendTime >= SEND_INTERVAL)
    {
        SendMarketData();
        g_lastSendTime = TimeCurrent();
    }

    // Poll for commands periodically
    if(TimeCurrent() - g_lastPollTime >= POLL_INTERVAL)
    {
        PollCommands();
        g_lastPollTime = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Timer event handler                                              |
//+------------------------------------------------------------------+
void OnTimer()
{
    if(!g_initialized)
        return;

    // Also check in timer in case no ticks are coming
    if(TimeCurrent() - g_lastSendTime >= SEND_INTERVAL)
    {
        SendMarketData();
        g_lastSendTime = TimeCurrent();
    }

    if(TimeCurrent() - g_lastPollTime >= POLL_INTERVAL)
    {
        PollCommands();
        g_lastPollTime = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| HTTP GET request using WebRequest                                |
//+------------------------------------------------------------------+
string HttpGet(string path)
{
    string url = g_baseUrl + path;

    if(DEBUG_MODE) Print("GET ", url);

    char postData[];
    char resultData[];
    string resultHeaders;

    // WebRequest returns -1 on error, 0 on success with HTTP error, >0 on success
    int res = WebRequest("GET", url, NULL, 5000, postData, resultData, resultHeaders);

    if(res == -1)
    {
        int errorCode = GetLastError();
        string errorDesc = ErrorDescription(errorCode);
        if(DEBUG_MODE)
        {
            Print("❌ WebRequest failed");
            Print("   Error code: ", errorCode);
            Print("   Description: ", errorDesc);
        }
        return "";
    }

    // Convert result to string
    string response = CharArrayToString(resultData, 0, WHOLE_ARRAY, CP_UTF8);

    if(DEBUG_MODE && StringLen(response) > 0)
        Print("Response (", res, "): ", StringSubstr(response, 0, MathMin(100, StringLen(response))));

    return response;
}

//+------------------------------------------------------------------+
//| URL encode a string                                              |
//+------------------------------------------------------------------+
string UrlEncode(string str)
{
    string result = "";
    string hex = "0123456789ABCDEF";

    for(int i = 0; i < StringLen(str); i++)
    {
        int c = StringGetChar(str, i);

        // Alphanumeric and some safe characters
        if((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') ||
           c == '-' || c == '_' || c == '.' || c == '~')
        {
            result += CharToString((uchar)c);
        }
        else
        {
            // Percent encode
            result += "%" + StringSubstr(hex, (c >> 4) & 0x0F, 1) + StringSubstr(hex, c & 0x0F, 1);
        }
    }

    return result;
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

    // Build URL with query parameters (GET request)
    string path = "/receive-data?";
    path += "type=market";
    path += "&symbol=" + UrlEncode(symbol);
    path += "&bid=" + DoubleToString(bid, digits);
    path += "&ask=" + DoubleToString(ask, digits);
    path += "&spread=" + IntegerToString(spread);
    path += "&digits=" + IntegerToString(digits);
    path += "&balance=" + DoubleToString(balance, 2);
    path += "&equity=" + DoubleToString(equity, 2);
    path += "&profit=" + DoubleToString(profit, 2);
    path += "&margin=" + DoubleToString(margin, 2);
    path += "&time=" + IntegerToString(TimeCurrent());

    string response = HttpGet(path);

    if(DEBUG_MODE && StringLen(response) > 0)
        Print("📤 Data sent successfully");
}

//+------------------------------------------------------------------+
//| Poll server for pending commands                                  |
//+------------------------------------------------------------------+
void PollCommands()
{
    string response = HttpGet("/get-commands");

    if(StringLen(response) == 0)
        return;

    if(DEBUG_MODE)
        Print("📥 Commands: ", StringSubstr(response, 0, MathMin(100, StringLen(response))));

    // Parse and execute commands
    ProcessCommands(response);
}

//+------------------------------------------------------------------+
//| Process commands from server                                      |
//+------------------------------------------------------------------+
void ProcessCommands(string jsonResponse)
{
    // Simple JSON parsing for commands array
    int commandsStart = StringFind(jsonResponse, "\"commands\":[");
    if(commandsStart == -1)
        return;

    commandsStart += 12;

    int commandsEnd = StringFind(jsonResponse, "]", commandsStart);
    if(commandsEnd == -1)
        return;

    string commandsStr = StringSubstr(jsonResponse, commandsStart, commandsEnd - commandsStart);

    // Find each command object
    int pos = 0;
    while(pos < StringLen(commandsStr))
    {
        int objStart = StringFind(commandsStr, "{", pos);
        if(objStart == -1)
            break;

        int objEnd = StringFind(commandsStr, "}", objStart);
        if(objEnd == -1)
            break;

        string cmdJson = StringSubstr(commandsStr, objStart, objEnd - objStart + 1);
        ExecuteCommand(cmdJson);

        pos = objEnd + 1;
    }
}

//+------------------------------------------------------------------+
//| Execute a single command                                          |
//+------------------------------------------------------------------+
void ExecuteCommand(string json)
{
    string type = ExtractJsonValue(json, "type");
    string message = ExtractJsonValue(json, "message");

    if(type == "alert")
    {
        Alert("📩 Server message: ", message);
        Print("✅ Alert displayed: ", message);
    }
    else if(type == "log")
    {
        Print("📝 Server log: ", message);
    }
    else if(type == "pong")
    {
        if(DEBUG_MODE)
            Print("💓 Heartbeat received");
    }
}

//+------------------------------------------------------------------+
//| Extract value from simple JSON                                    |
//+------------------------------------------------------------------+
string ExtractJsonValue(string json, string key)
{
    string search = "\"" + key + "\":\"";
    int start = StringFind(json, search);

    if(start >= 0)
    {
        start += StringLen(search);
        int end = StringFind(json, "\"", start);
        if(end > start)
            return StringSubstr(json, start, end - start);
    }

    search = "\"" + key + "\":";
    start = StringFind(json, search);

    if(start >= 0)
    {
        start += StringLen(search);
        int end = StringFind(json, ",", start);
        if(end == -1)
            end = StringFind(json, "}", start);
        if(end > start)
            return StringSubstr(json, start, end - start);
    }

    return "";
}

//+------------------------------------------------------------------+
//| Helper function for minimum                                       |
//+------------------------------------------------------------------+
int MathMin(int a, int b)
{
    return (a < b) ? a : b;
}
//+------------------------------------------------------------------+
