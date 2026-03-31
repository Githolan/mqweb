//+------------------------------------------------------------------+
//|                                          WebSenderEA.mq4          |
//|                        Expert Advisor que envía datos a la web   |
//|                     Usa la librería vivazzi/mql_requests         |
//+------------------------------------------------------------------+
#property copyright "MQL4 Web Communication"
#property link      "https://github.com/vivazzi/mql_requests"
#property version   "1.00"
#property strict

// Incluir la librería de requests
// NOTA: Primero debes instalar mql_requests desde:
// https://github.com/vivazzi/mql_requests
// Copia la carpeta Include/requests/ a tu terminal MQL4/Include/
#include <requests/requests.mqh>

//+------------------------------------------------------------------+
//| Parámetros de entrada                                            |
//+------------------------------------------------------------------+
input string   SERVER_URL     = "https://your-api.com/receive-data";  // URL del servidor
input bool     SEND_ON_TICK   = false;                                // Enviar en cada tick
input bool     SEND_ON_TRADE  = true;                                 // Enviar al operar
input int      SEND_INTERVAL  = 60;                                   // Intervalo de envío (segundos)
input string   API_KEY        = "";                                   // Clave API opcional
input bool     DEBUG_MODE     = true;                                 // Mostrar mensajes de debug

//+------------------------------------------------------------------+
//| Variables globales                                               |
//+------------------------------------------------------------------+
Requests requests;
datetime last_send_time = 0;
int total_sent = 0;
int total_errors = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("========================================");
    Print("WebSenderEA iniciado");
    Print("Servidor: ", SERVER_URL);
    Print("========================================");

    // Probar conexión al inicio
    if(DEBUG_MODE)
    {
        Print("Probando conexión al servidor...");
        TestConnection();
    }

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("WebSenderEA detenido. Total enviados: ", total_sent, " Errores: ", total_errors);

    // Cerrar conexión
    requests.close();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Enviar datos en cada tick si está activado
    if(SEND_ON_TICK)
    {
        SendMarketData();
    }
}

//+------------------------------------------------------------------+
//| Trade event handler                                              |
//+------------------------------------------------------------------+
void OnTrade()
{
    // Enviar datos cuando ocurre un evento de trading
    if(SEND_ON_TRADE)
    {
        SendTradeEvent();
    }
}

//+------------------------------------------------------------------+
//| Timer event handler                                              |
//+------------------------------------------------------------------+
void OnTimer()
{
    // Enviar datos periódicamente
    static datetime timer_last_send = 0;

    if(TimeCurrent() - timer_last_send >= SEND_INTERVAL)
    {
        SendMarketData();
        timer_last_send = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Enviar datos del mercado al servidor                             |
//+------------------------------------------------------------------+
bool SendMarketData()
{
    // Verificar intervalo mínimo entre envíos
    if(TimeCurrent() - last_send_time < SEND_INTERVAL)
    {
        return false;
    }

    // Preparar datos del mercado
    string symbol = _Symbol;
    double bid = MarketInfo(symbol, MODE_BID);
    double ask = MarketInfo(symbol, MODE_ASK);
    double point = MarketInfo(symbol, MODE_POINT);
    int digits = (int)MarketInfo(symbol, MODE_DIGITS);
    int spread = (int)MarketInfo(symbol, MODE_SPREAD);

    // Obtener datos de la cuenta
    double balance = AccountBalance();
    double equity = AccountEquity();
    double margin = AccountMargin();
    double profit = AccountProfit();

    // Construir datos a enviar
    RequestData data;
    data.add("symbol", symbol);
    data.add("bid", DoubleToString(bid, digits));
    data.add("ask", DoubleToString(ask, digits));
    data.add("spread", IntegerToString(spread));
    data.add("balance", DoubleToString(balance, 2));
    data.add("equity", DoubleToString(equity, 2));
    data.add("profit", DoubleToString(profit, 2));
    data.add("margin", DoubleToString(margin, 2));
    data.add("timestamp", IntegerToString(TimeCurrent()));

    // Agregar API key si existe
    if(API_KEY != "")
    {
        data.add("api_key", API_KEY);
    }

    // Enviar datos
    Response response = requests.post(SERVER_URL, data);

    // Procesar respuesta
    if(response.error != "")
    {
        if(DEBUG_MODE)
        {
            Print("ERROR al enviar datos: ", response.error);
        }
        total_errors++;
        return false;
    }

    if(DEBUG_MODE)
    {
        Print("Datos enviados correctamente. Respuesta: ", response.text);
    }

    last_send_time = TimeCurrent();
    total_sent++;

    return true;
}

//+------------------------------------------------------------------+
//| Enviar evento de trading                                         |
//+------------------------------------------------------------------+
bool SendTradeEvent()
{
    // Obtener información de posiciones abiertas
    int total_orders = OrdersTotal();
    int total_positions = 0;
    double total_profit = 0;

    for(int i = 0; i < total_orders; i++)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderType() == OP_BUY || OrderType() == OP_SELL)
            {
                total_positions++;
                total_profit += OrderProfit();
            }
        }
    }

    // Preparar datos del evento
    RequestData data;
    data.add("event_type", "trade");
    data.add("symbol", _Symbol);
    data.add("total_positions", IntegerToString(total_positions));
    data.add("total_profit", DoubleToString(total_profit, 2));
    data.add("balance", DoubleToString(AccountBalance(), 2));
    data.add("equity", DoubleToString(AccountEquity(), 2));
    data.add("timestamp", IntegerToString(TimeCurrent()));

    if(API_KEY != "")
    {
        data.add("api_key", API_KEY);
    }

    Response response = requests.post(SERVER_URL, data);

    if(response.error != "")
    {
        if(DEBUG_MODE)
        {
            Print("ERROR al enviar evento: ", response.error);
        }
        total_errors++;
        return false;
    }

    if(DEBUG_MODE)
    {
        Print("Evento de trading enviado. Respuesta: ", response.text);
    }

    total_sent++;
    return true;
}

//+------------------------------------------------------------------+
//| Probar conexión con el servidor                                  |
//+------------------------------------------------------------------+
void TestConnection()
{
    RequestData data;
    data.add("test", "connection");
    data.add("timestamp", IntegerToString(TimeCurrent()));

    Response response = requests.post(SERVER_URL, data);

    if(response.error != "")
    {
        Print("TEST DE CONEXIÓN FALLIDO: ", response.error);
        Print("Verifica:");
        Print("1. La URL del servidor es correcta");
        Print("2. Tienes conexión a internet");
        Print("3. Los DLLs están permitidos en MT4");
        Print("4. La URL está en la lista de WebRequest permitidos");
    }
    else
    {
        Print("TEST DE CONEXIÓN EXITOSO!");
        Print("Respuesta del servidor: ", response.text);
    }
}
//+------------------------------------------------------------------+
