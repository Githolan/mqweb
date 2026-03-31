# MQL4 Web Communication - Implementation Guide

## Overview

This guide provides proven solutions for communicating from MQL4 Expert Advisors to web services. The libraries listed below are from GitHub with significant stars and active development, ensuring they work around MQL4 sandbox limitations.

---

## Recommended Solutions (by stars & relevance)

### 1. vivazzi/mql_requests (54 stars) ⭐ RECOMMENDED

**GitHub:** https://github.com/vivazzi/mql_requests

**Description:** "Requests is a simple HTTP library for mql4, built for human beings"

**Why this solves sandbox issues:**
- Uses WinINET.dll directly (Windows native API), bypassing MQL4's WebRequest restrictions
- Handles both HTTP and HTTPS (port 443)
- Automatic SSL certificate handling
- Connection pooling for efficiency
- Very simple API, similar to Python's requests library

**Installation:**
1. Download: https://github.com/vivazzi/mql_requests/archive/refs/heads/main.zip
2. Copy `Include/requests/` folder to your MT4 terminal's `MQL4/Include/` directory
3. Enable DLLs in MT4: Tools → Options → Expert Advisors → ✅ "Allow DLL imports"

**Usage Example:**

```mql4
#include <requests/requests.mqh>

input string API_URL = "https://your-api.com/receive-data";

Requests requests;

// Send data to web service
bool SendTradeData(string symbol, double price, double volume, int action)
{
    RequestData data;
    data.add("symbol", symbol);
    data.add("price", DoubleToString(price, 5));
    data.add("volume", DoubleToString(volume, 2));
    data.add("action", IntegerToString(action));
    data.add("timestamp", IntegerToString(TimeCurrent()));

    Response response = requests.post(API_URL, data);

    if (response.error != "")
    {
        Print("Error: ", response.error);
        return false;
    }

    Print("Response: ", response.text);
    return true;
}

int OnInit()
{
    // Example: Send data when EA starts
    SendTradeData("EURUSD", 1.0850, 0.1, 1);
    return INIT_SUCCEEDED;
}
```

**For JSON data:**

```mql4
bool SendJsonData(string json_string)
{
    // Note: This library sends form-encoded by default
    // For raw JSON, modify the Content-Type header in requests.mqh

    string json_data = "{\"symbol\":\"EURUSD\",\"price\":1.0850}";

    Response response = requests.post(API_URL, json_data);

    return (response.error == "");
}
```

---

### 2. vdemydiuk/mtapi (650 stars) 🔧 ENTERPRISE SOLUTION

**GitHub:** https://github.com/vdemydiuk/mtapi

**Description:** "MetaTrader API (terminal bridge)" - Full .NET bridge using WCF framework

**Why this works:**
- Complete bridge architecture bypassing MT4 sandbox entirely
- Bidirectional communication (.NET ↔ MT4)
- Full trading API access from external applications
- TCP/Pipe connections (local and remote)

**Installation:**
1. Download installer: https://github.com/vdemydiuk/mtapi/releases
2. Run `MtApiInstaller_setup.exe`
3. Copy `MtApi.ex4` to your MT4 `MQL4/Experts/` folder
4. Attach MtApi.ex4 to any chart in MT4
5. Use .NET API in your external application

**Usage Example (C#):**

```csharp
using MtApi;

// Create client
var mtapi = new MtApi5Client();

// Connect to MT4 (default port 8228)
mtapi.BeginConnect(8228);

// Send data from external app
private void SendDataFromWeb()
{
    // This bridge allows bidirectional communication
    // Your web service can send commands TO MT4
    // And MT4 can send data TO your web service via .NET
}

// Receive quotes from MT4
mtapi.QuoteUpdate += (s, e) => {
    Console.WriteLine($"{e.Quote.Instrument}: {e.Quote.Bid}");
};
```

**Use case:** Best for complex applications needing full bidirectional control.

---

### 3. xefino/mql-http (3 stars) 📝 ALTERNATIVE

**GitHub:** https://github.com/xefino/mql-http

**Description:** "HTTP request library compatible with MQL4 and MQL5"

Similar to mql_requests, uses WinINET directly. Good alternative if you need different features.

---

## Comparison Table

| Library | Stars | Approach | Complexity | Best For |
|---------|-------|----------|------------|----------|
| **mql_requests** | 54 | WinINET direct | ⭐ Simple | Quick HTTP requests from EA |
| **mtapi** | 650 | .NET Bridge | ⭐⭐⭐ Complex | Enterprise apps, full control |
| **mql-http** | 3 | WinINET direct | ⭐ Simple | Alternative HTTP library |

---

## Server-Side Example (Node.js)

Create a simple server to receive data from your EA:

```javascript
const express = require('express');
const app = express();

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Receive data from MQL4
app.post('/receive-data', (req, res) => {
    console.log('Received from MT4:', req.body);

    // Process data: save to database, send to trading system, etc.
    const { symbol, price, volume, action, timestamp } = req.body;

    // Send response back to EA
    res.json({
        success: true,
        received: true,
        processed: timestamp
    });
});

app.listen(3000, () => {
    console.log('Server running on port 3000');
});
```

---

## Common Issues & Solutions

### Issue: "WebRequest not allowed"
**Solution:** Enable URLs in MT4:
1. Tools → Options → Expert Advisors
2. Click "WebRequest" button
3. Add your API URL to allowed list

### Issue: "DLL imports not allowed"
**Solution:**
1. Tools → Options → Expert Advisors
2. Check ✅ "Allow DLL imports"
3. Restart MT4 terminal

### Issue: SSL/HTTPS errors
**Solution:** mql_requests handles SSL automatically. The library includes code to ignore unknown CA certificates for HTTPS connections.

---

## Quick Start Checklist

- [ ] Download mql_requests from GitHub
- [ ] Copy `requests.mqh` to `MQL4/Include/requests/`
- [ ] Enable DLL imports in MT4
- [ ] Add your API URL to WebRequest allowed list (if using WebRequest)
- [ ] Test with simple GET request first
- [ ] Implement POST request for your data
- [ ] Deploy server-side endpoint to receive data

---

## Conclusion

For most use cases, **vivazzi/mql_requests** is the recommended solution because:
1. ✅ 54 stars on GitHub (proven working code)
2. ✅ Simple API ("built for human beings")
3. ✅ Bypasses MQL4 sandbox using WinINET
4. ✅ Handles HTTP/HTTPS automatically
5. ✅ Easy installation and usage

The library directly addresses the sandbox communication issues you mentioned by using Windows native APIs instead of MQL4's restricted WebRequest function.
