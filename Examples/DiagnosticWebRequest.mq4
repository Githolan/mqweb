//+------------------------------------------------------------------+
//|                                  DiagnosticWebRequest.mq4       |
//|                        Diagnóstico de WebRequest para MT4       |
//+------------------------------------------------------------------+
#property copyright "MQL4-WEB Diagnostic"
#property version   "1.00"
#property strict

// Este script prueba la conectividad WebRequest y muestra información detallada

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("====================================================");
    Print("         WEBREQUEST DIAGNOSTIC SCRIPT");
    Print("====================================================");
    Print("");

    // Test 1: HTTP simple (sin HTTPS)
    Print("TEST 1: HTTP simple (sin encriptación)");
    TestWebRequest("http://httpbin.org/get", "HTTP");
    Print("");

    // Test 2: HTTPS con certificado conocido
    Print("TEST 2: HTTPS sitio conocido");
    TestWebRequest("https://www.google.com/", "HTTPS Google");
    Print("");

    // Test 3: Nuestro servidor
    Print("TEST 3: Nuestro servidor HTTPS");
    TestWebRequest("https://mqweb.holancloud.com/health", "Nuestro servidor");
    Print("");

    // Test 4: Sin puerto explícito
    Print("TEST 4: Nuestro servidor sin puerto");
    TestWebRequest("https://mqweb.holancloud.com/health", "Sin puerto");
    Print("");

    Print("====================================================");
    Print("         DIAGNÓSTICO COMPLETADO");
    Print("====================================================");
}

//+------------------------------------------------------------------+
//| Test WebRequest and print detailed info                          |
//+------------------------------------------------------------------+
void TestWebRequest(string url, string testName)
{
    Print("--- ", testName, " ---");
    Print("URL: ", url);

    char postData[];
    char resultData[];
    string resultHeaders;

    ResetLastError();

    int httpCode = WebRequest("GET", url, NULL, 10000, postData, resultData, resultHeaders);
    int errorCode = GetLastError();

    Print("HTTP Code: ", httpCode);
    Print("GetLastError(): ", errorCode);
    Print("Error Description: ", ErrorDescription(errorCode));

    // Interpretar códigos de error
    if(httpCode == -1)
    {
        Print("❌ Error de conexión local");

        switch(errorCode)
        {
            case 5200:
                Print("   → 5200: URL no permitida o error de conexión");
                Print("   → Verificar URL en Tools → Options → Expert Advisors");
                Print("   → Verificar conexión a internet");
                break;
            case 5201:
                Print("   → 5201: Error de conexión");
                break;
            case 5202:
                Print("   → 5202: Timeout");
                break;
            case 5203:
                Print("   → 5203: Error HTTP/TLS");
                Print("   → Posible problema de certificado SSL/TLS");
                Print("   → MT4 puede no soportar TLS 1.2+");
                break;
            case 4060:
                Print("   → 4060: Función no permitida");
                Print("   → WebRequest solo funciona en EA/Scripts, no en indicadores");
                break;
            default:
                Print("   → Error desconocido: ", errorCode);
        }
    }
    else if(httpCode >= 200 && httpCode < 300)
    {
        Print("✅ Conexión exitosa!");
    }
    else if(httpCode >= 300 && httpCode < 400)
    {
        Print("⚠️ Redirección: ", httpCode);
    }
    else if(httpCode >= 400 && httpCode < 500)
    {
        Print("❌ Error cliente: ", httpCode);
        if(httpCode == 403)
            Print("   → 403 Forbidden - Cloudflare bloqueando");
        if(httpCode == 404)
            Print("   → 404 Not Found");
    }
    else if(httpCode >= 500)
    {
        Print("❌ Error servidor: ", httpCode);
    }

    // Mostrar headers de respuesta
    if(StringLen(resultHeaders) > 0)
    {
        Print("Response Headers:");
        string headers[];
        StringSplit(resultHeaders, '\n', headers);
        for(int i = 0; i < ArraySize(headers); i++)
        {
            if(StringLen(headers[i]) > 0)
                Print("   ", headers[i]);
        }
    }

    // Mostrar body de respuesta (primeros 500 caracteres)
    string body = CharArrayToString(resultData, 0, WHOLE_ARRAY, CP_UTF8);
    if(StringLen(body) > 0)
    {
        Print("Response Body (primeros 500 chars):");
        Print("   ", StringSubstr(body, 0, MathMin(500, StringLen(body))));
    }

    Print("");
}

//+------------------------------------------------------------------+
//| Helper: Error Description                                        |
//+------------------------------------------------------------------+
string ErrorDescription(int errorCode)
{
    switch(errorCode)
    {
        case 0:     return "No error";
        case 4060:  return "Function is not allowed";
        case 5200:  return "URL not allowed or connection error";
        case 5201:  return "Connection error";
        case 5202:  return "Timeout";
        case 5203:  return "HTTP/TLS error";
        default:    return "Unknown error";
    }
}
