# Detalles Técnicos - Cómo mql_requests Bypass el Sandbox de MQL4

Este documento explica técnicamente cómo la biblioteca `vivazzi/mql_requests` logra comunicarse con servidores web desde el entorno restringido de MQL4.

---

## 🎯 El Problema del Sandbox de MQL4

### Limitaciones de WebRequest nativo

MQL4 tiene una función nativa `WebRequest()` que permite hacer peticiones HTTP, pero tiene varias limitaciones:

1. **Lista blanca de URLs** - Solo puede conectarse a URLs previamente autorizadas
2. **Configuración manual** - El usuario debe agregar cada URL en Tools → Options → Expert Advisors → WebRequest
3. **Tiempo de espera limitado** - Puede tener timeouts muy cortos
4. **Manejo de SSL limitado** - Problemas con certificados SSL autofirmados
5. **Sin persistencia de conexión** - Cada petición abre una nueva conexión

### Código típico con WebRequest (problemático)

```mql4
char data[];
char result[];
string resultHeaders;

// Problema: La URL debe estar en la lista blanca
// Problema: No maneja bien errores de SSL
// Problema: No reutiliza conexiones
int res = WebRequest(
    "https://api.example.com/data",
    "POST",
    "Content-Type: application/json\r\n",
    5000,
    data,
    result,
    resultHeaders
);

if(res == -1) {
    int error = GetLastError();
    // Error 4060 - URL no autorizada
    // Error 5200 - Error de conexión
}
```

---

## 🔧 La Solución: WinINET Directo

### ¿Qué es WinINET?

**WinINET** (Windows Internet API) es la API de Windows que utilizan Internet Explorer y otras aplicaciones de Windows para navegar por internet. Es una API nativa de Windows que:

- Precede al MQL4 en décadas
- Está diseñada para aplicaciones de escritorio
- No tiene las restricciones del sandbox de MQL4
- Maneja automáticamente SSL, proxies, y cookies

### ¿Por qué funciona desde MQL4?

La clave es que MQL4 **permite importar funciones de DLLs externas**. Aunque el entorno de MQL4 está restringido, la llamada a una DLL de Windows (wininet.dll) se ejecuta fuera del sandbox de MQL4, en el contexto de Windows.

```
┌─────────────────────────────────────────────────────────────┐
│                    MetaTrader 4                             │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐      ┌─────────────────────────────┐  │
│  │  MQL4 EA        │─────│  WinINET (wininet.dll)       │  │
│  │                 │ DLL  │                             │  │
│  │  requests.get() │─────│  InternetOpenUrlW()          │  │
│  │  requests.post()│      │  HttpSendRequestW()         │  │
│  └─────────────────┘      └─────────────────────────────┘  │
│           │                          │                     │
│      Sandbox MQL4          WinINET (Fuera del sandbox)     │
│           │                          │                     │
│      Restringido               Sin restricciones           │
│           │                          │                     │
└───────────┼──────────────────────────┼─────────────────────┘
            │                          │
            │     ↓↓↓↓↓↓↓↓↓↓↓↓        │
            │                          │
            ▼                          ▼
         ❌ Limitado               ✅ Conexión directa
                                      a internet
```

---

## 📄 Código Fuente de mql_requests

### Importación de funciones WinINET

El archivo `requests.mqh` importa directamente las funciones de wininet.dll:

```mql4
#import "wininet.dll"

// Funciones de WinINET importadas
DWORD InternetAttemptConnect(DWORD dwReserved);
HINTERNET InternetOpenW(LPCTSTR lpszAgent, DWORD dwAccessType,
                       LPCTSTR lpszProxyName, LPCTSTR lpszProxyBypass,
                       DWORD dwFlags);
HINTERNET InternetConnectW(HINTERNET hInternet, LPCTSTR lpszServerName,
                          INTERNET_PORT nServerPort, LPCTSTR lpszUsername,
                          LPCTSTR lpszPassword, DWORD dwService,
                          DWORD dwFlags, DWORD_PTR dwContext);
HINTERNET HttpOpenRequestW(HINTERNET hConnect, LPCTSTR lpszVerb,
                          LPCTSTR lpszObjectName, LPCTSTR lpszVersion,
                          LPCTSTR lpszReferer, int lplpszAcceptTypes,
                          uint dwFlags, DWORD_PTR dwContext);
BOOL HttpSendRequestW(HINTERNET hRequest, LPCTSTR lpszHeaders,
                     DWORD dwHeadersLength, LPVOID lpOptional[],
                     DWORD dwOptionalLength);
HINTERNET InternetOpenUrlW(HINTERNET hInternet, LPCTSTR lpszUrl,
                          LPCTSTR lpszHeaders, DWORD dwHeadersLength,
                          uint dwFlags, DWORD_PTR dwContext);
BOOL InternetReadFile(HINTERNET hFile, LPVOID lpBuffer[],
                     DWORD dwNumberOfBytesToRead,
                     LPDWORD lpdwNumberOfBytesRead);
BOOL InternetCloseHandle(HINTERNET hInternet);
BOOL InternetSetOptionW(HINTERNET hInternet, DWORD dwOption,
                       LPDWORD lpBuffer, DWORD dwBufferLength);
BOOL InternetQueryOptionW(HINTERNET hInternet, DWORD dwOption,
                         LPDWORD lpBuffer, LPDWORD lpdwBufferLength);

#import
```

### Flujo de una petición POST

```mql4
Response post(string url, string _str_data) {
    // 1. Verificar que los DLLs están permitidos
    check_dll(error);

    // 2. Abrir sesión de WinINET (se mantiene abierta)
    if (h_session <= 0 || h_connect <= 0) {
        open(url);
        // Esto llama a InternetOpenW() e InternetConnectW()
        // Solo se hace una vez por host
    }

    // 3. Crear la petición HTTP
    h_request = HttpOpenRequestW(
        h_connect,           // Conexión abierta (reutilizada)
        "POST",              // Método
        path,                // Ruta de la URL
        "HTTP/1.1",          // Versión
        NULL,                // Referer
        0,                   // Accept types
        flags,               // Flags (HTTPS, etc.)
        0                    // Context
    );

    // 4. Enviar la petición
    HttpSendRequestW(
        h_request,           // Request handle
        headers,             // Headers HTTP
        headers_len,         // Length of headers
        data,                // POST data
        data_len             // Length of POST data
    );

    // 5. Leer la respuesta
    InternetReadFile(h_request, buffer, size, bytes_read);

    // 6. Cerrar el request (pero NO la sesión/conexión)
    InternetCloseHandle(h_request);

    return response;
}
```

### Manejo automático de errores SSL

El código incluye manejo específico para errores de certificado SSL:

```mql4
// Flags para HTTPS
uint flags = INTERNET_FLAG_KEEP_CONNECTION |
             INTERNET_FLAG_RELOAD |
             INTERNET_FLAG_PRAGMA_NOCACHE;

if (port == 443) {
    flags |= INTERNET_FLAG_SECURE;  // Activar SSL
}

// Reintentar hasta 3 veces si hay error de certificado
while (trying < 3) {
    h_send = HttpSendRequestW(h_request, headers, ...);

    if (h_send <= 0) {
        int err = GetLastError();

        // Error 12045: ERROR_INTERNET_INVALID_CA
        // (Certificado inválido o autofirmado)
        if (err == ERROR_INTERNET_INVALID_CA) {
            // Obtener flags de seguridad actuales
            InternetQueryOptionW(h_request,
                               INTERNET_OPTION_SECURITY_FLAGS,
                               dwFlags, dwBuffLen);

            // Agregar flag para ignorar CA desconocido
            dwFlags |= SECURITY_FLAG_IGNORE_UNKNOWN_CA;

            // Aplicar nuevos flags
            InternetSetOptionW(h_request,
                             INTERNET_OPTION_SECURITY_FLAGS,
                             dwFlags, sizeof(dwFlags));

            // Reintentar
            trying++;
            continue;
        }
    }
    break;
}
```

---

## 🔄 Reutilización de Conexiones

Una ventaja clave de mql_requests es que **reutiliza las conexiones**, lo que mejora el rendimiento:

```mql4
bool open(string url) {
    // Si ya hay una conexión al mismo host, no volver a conectar
    if (h_session > 0 || h_connect > 0) {
        if (is_same_host(url)) {
            return true;  // Ya conectado a este host
        }
        close();  // Nuevo host, cerrar conexión anterior
    }

    // Crear nueva conexión
    InternetAttemptConnect(0);
    h_session = InternetOpenW(...);
    h_connect = InternetConnectW(...);

    return true;
}

bool is_same_host(string url) {
    _UrlParts _url_parts;
    _url_parts.split(url);

    // Comparar con la conexión actual
    if (_url_parts.host != host) return false;
    return true;
}
```

Esto significa que:
- La primera petición establece la conexión
- Las siguientes peticiones al mismo host reutilizan la conexión
- Mucho más rápido que WebRequest que abre nueva conexión cada vez

---

## 📊 Comparación Rendimiento

### WebRequest nativo

```
Petición 1: [Conexión] → [Handshake SSL] → [Enviar] → [Recibir] → [Cerrar]  = ~500ms
Petición 2: [Conexión] → [Handshake SSL] → [Enviar] → [Recibir] → [Cerrar]  = ~500ms
Petición 3: [Conexión] → [Handshake SSL] → [Enviar] → [Recibir] → [Cerrar]  = ~500ms
Total: 1500ms
```

### mql_requests con WinINET

```
Petición 1: [Conexión + Handshake] → [Enviar] → [Recibir]  = ~500ms
Petición 2: [Enviar (conexión reutilizada)] → [Recibir]    = ~50ms
Petición 3: [Enviar (conexión reutilizada)] → [Recibir]    = ~50ms
Total: 600ms
```

**Resultado:** 2.5x más rápido con múltiples peticiones.

---

## 🛡️ Seguridad

### Certificados SSL

mql_requests permite configurar el comportamiento SSL:

```mql4
// Opciones de seguridad disponibles
#define INTERNET_FLAG_SECURE 0x00800000     // Usar SSL/TLS
#define SECURITY_FLAG_IGNORE_UNKNOWN_CA 0x00000100  // Ignorar CA desconocido
#define INTERNET_OPTION_SECURITY_FLAGS 31    // Opción para configurar SSL
```

### Ventajas

- ✅ Soporte completo de HTTPS
- ✅ Manejo automático de certificados
- ✅ Compatible con proxies corporativos
- ✅ Soporta autenticación básica y digest

### Precauciones

- ⚠️ Ignorar errores de certificado puede ser un riesgo de seguridad
- ⚠️ Usar solo con servidores de confianza
- ⚠️ Considerar validar el certificado manualmente para producción

---

## 📝 Conclusión

La biblioteca `vivazzi/mql_requests` soluciona el problema del sandbox de MQL4 mediante:

1. **DLL Imports** - Usa funciones de Windows (wininet.dll) que se ejecutan fuera del sandbox
2. **Conexión persistente** - Reutiliza conexiones HTTP para mejor rendimiento
3. **Manejo robusto de SSL** - Incluye código para manejar errores de certificado
4. **API simple** - Oculta la complejidad de WinINET detrás de una interfaz sencilla

Esta es una solución probada con **54 estrellas en GitHub** que ha sido utilizada por muchos traders para comunicar sus EAs con servicios web.

---

## 🔗 Referencias

- **Repositorio:** https://github.com/vivazzi/mql_requests
- **Documentación WinINET:** https://docs.microsoft.com/en-us/windows/win32/api/wininet/
- **Foro MQL5:** https://www.mql5.com/en/articles
