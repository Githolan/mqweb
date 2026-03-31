# MQL4 Web Communication

**Sistema completo para comunicar Expert Advisors MQL4 con servicios web**

Solución probada para enviar datos desde MetaTrader 4 a servidores web, bypassando las limitaciones del sandbox de MQL4 usando la biblioteca **vivazzi/mql_requests**.

---

## 🌟 Características

- ✅ **Bypass completo del sandbox MQL4** - TCP directo con WinSock
- ✅ **Bidireccional** - MT4 → Web y Web → MT4
- ✅ **Sin configuración de "webs confiables"** - TCP no usa HTTP
- ✅ **Conexión persistente** - Reconexión automática
- ✅ **Dashboard web incluido** - Interfaz para ver datos y enviar comandos
- ✅ **Fácil de usar** - Solo 3 archivos, configuración simple

## 🎯 Dos Opciones Disponibles

| Opción | Direccional | Complejidad | Cuándo usar |
|--------|-------------|-------------|-------------|
| **TCP (Nuevo)** ✅ | Bidireccional | Simple | **Recomendado** - Solución robusta, bypass completo sandbox |
| **HTTP (mql_requests)** | Unidireccional | Simple | Si solo necesitas enviar datos MT4 → Web |

---

## 📁 Estructura del Proyecto

```
MQL4-WEB/
├── Examples/
│   ├── TcpBidirectionalEA.mq4   ← EA con TCP (bidireccional) ✨ NUEVO
│   ├── tcp-server.js            ← Servidor TCP + HTTP ✨ NUEVO
│   ├── dashboard.html            ← Dashboard web ✨ NUEVO
│   ├── WebSenderEA.mq4          ← EA con HTTP (unidireccional)
│   └── server.js                ← Servidor HTTP solo
├── TCP-QUICK-START.md           ← Guía rápida TCP ✨ NUEVO
├── MQL4-Web-Communication-Guide.md  ← Guía completa
├── INSTALLATION.md               ← Instrucciones detalladas
├── package.json                 ← Dependencias
└── README.md                     ← Este archivo
```

---

## 🚀 Inicio Rápido

### Opción 1: TCP Bidireccional (Recomendado) ✨

```bash
# 1. Iniciar el servidor TCP
cd MQL4-WEB
npm install
npm run start:tcp

# 2. Abrir dashboard
# Ve a http://localhost:3000 en tu navegador

# 3. En MT4
# - Abre TcpBidirectionalEA.mq4 en MetaEditor
# - Compila (F7)
# - Arrastra el EA a un gráfico
# - ¡Verás "🟢 Conectado" en el dashboard!
```

[📖 Guía completa TCP → TCP-QUICK-START.md](TCP-QUICK-START.md)

---

### Opción 2: HTTP Unidireccional

```bash
# 1. Instalar mql_requests
curl -L https://github.com/vivazzi/mql_requests/archive/refs/heads/main.zip -o mql_requests.zip
unzip mql_requests.zip
# Copia Include/requests/ a MT4/MQL4/Include/

# 2. Iniciar el servidor HTTP
cd MQL4-WEB
npm install
npm start

# 3. En MT4
# - Abre WebSenderEA.mq4 en MetaEditor
# - Compila (F7)
# - Arrastra el EA a un gráfico
```

---

## 📖 Documentación

| Archivo | Descripción |
|---------|-------------|
| **[TCP-QUICK-START.md](TCP-QUICK-START.md)** ✨ | Guía rápida del sistema TCP bidireccional |
| **[MQL4-Web-Communication-Guide.md](MQL4-Web-Communication-Guide.md)** | Guía completa con todas las opciones disponibles |
| **[INSTALLATION.md](INSTALLATION.md)** | Instrucciones detalladas de instalación paso a paso |
| **[TECHNICAL-DETAILS.md](TECHNICAL-DETAILS.md)** | Explicación técnica de cómo funcionan las soluciones |

---

## 💻 Ejemplo de Uso

### TCP Bidireccional (Recomendado)

**MQL4 - Envía datos automáticamente cada 3 segundos:**
```mql4
// TcpBidirectionalEA.mq4
// Conexión TCP automática, reconexión, envío de datos
void OnTick() {
    if(g_connected && TimeCurrent() - g_lastSendTime >= 3) {
        SendMarketData(); // Envía bid, ask, balance, equity...
    }
}
```

**Web - Enviar comando a MT4:**
```javascript
// Desde el dashboard o tu app
await fetch('/command', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
        type: 'alert',
        message: '¡Hola desde la web!'
    })
});
// MT4 muestra: Alert("📩 Mensaje del servidor: ¡Hola desde la web!")
```

---

### HTTP Unidireccional (mql_requests)

**MQL4 - Enviar datos:**
```mql4
#include <requests/requests.mqh>

Requests requests;

RequestData data;
data.add("symbol", "EURUSD");
data.add("bid", "1.0850");
data.add("ask", "1.0851");

Response response = requests.post("http://localhost:3000/receive-data", data);
```

**Node.js - Recibir datos:**
```javascript
app.post('/receive-data', (req, res) => {
    console.log('Datos recibidos:', req.body);
    res.json({ success: true });
});
```

---

## 🎯 Soluciones Disponibles

### TCP Bidireccional (Recomendado) ✨

**TcpBidirectionalEA + tcp-server.js**
- Ideal para: Comunicación bidireccional completa
- Ventajas:
  - ✅ Sin "webs confiables"
  - ✅ Bypass completo sandbox
  - ✅ Dashboard web incluido
  - ✅ Reconexión automática
- Archivos: `TcpBidirectionalEA.mq4`, `tcp-server.js`, `dashboard.html`

### HTTP Unidireccional

**vivazzi/mql_requests** (54 ⭐)
- GitHub: https://github.com/vivazzi/mql_requests
- Ideal para: Solo enviar datos MT4 → Web
- Ventajas: API simple, bypass sandbox HTTP
- Archivo: `WebSenderEA.mq4`

### Bridge Empresarial

**vdemydiuk/mtapi** (650 ⭐)
- GitHub: https://github.com/vdemydiuk/mtapi
- Ideal para: Aplicaciones complejas con control total
- Ventajas: Bridge .NET completo, control total
- Requiere: .NET Framework, instalador

---

## 🔧 Solución de Problemas

### Error: "DLL function call failed not allowed"
```
Solución: Tools → Options → Expert Advisors → ✅ "Allow DLL imports"
```

### Error: "Error InternetOpenUrlW"
```
Solución: Verifica conexión a internet y ejecuta MT4 como administrador
```

### Error: SSL Certificate errors
```
Solución: mql_requests maneja SSL automáticamente. Para desarrollo usa http://
```

Más soluciones en [INSTALLATION.md](INSTALLATION.md)

---

## 📊 Comparación de Bibliotecas

| Biblioteca | Estrellas | Complejidad | Mejor Para |
|------------|----------|-------------|------------|
| **mql_requests** | 54 | ⭐ Simple | HTTP requests desde EA |
| **mtapi** | 650 | ⭐⭐⭐ Compleja | Apps empresariales |

---

## 🛠️ Requisitos Técnicos

**Para TCP Bidireccional:**
- **MetaTrader 4** con MetaEditor
- **Node.js** v14+ (para el servidor)
- **Windows** (ws2_32.dll es nativo de Windows)
- **Permisos de DLL** en MT4

**Para HTTP Unidireccional:**
- Todo lo anterior **más**
- **mql_requests** desde GitHub (descargar e instalar)

---

## 🔧 Comparación: TCP vs HTTP

| Problema | HTTP/WebRequest | TCP WinSock |
|----------|-----------------|-------------|
| Requiere "webs confiables" | ✅ Sí | ❌ **No** |
| Sandbox MQL4 filtra | ✅ Sí | ❌ **No** |
| Funciona con cualquier broker | ❌ No | ✅ **Sí** |
| Bidireccional | ❌ No | ✅ **Sí** |
| Conexión persistente | ❌ No | ✅ **Sí** |

---

## 📄 Licencia

Este proyecto es código abierto. La biblioteca `mql_requests` está licenciada bajo MIT.

---

## 🤝 Contribuciones

Este proyecto es una guía de implementación. Para contribuir a la biblioteca principal:
- **mql_requests:** https://github.com/vivazzi/mql_requests
- **mtapi:** https://github.com/vdemydiuk/mtapi

---

## 📞 Soporte

- **Issues de mql_requests:** https://github.com/vivazzi/mql_requests/issues
- **Foro MQL5:** https://www.mql5.com/en/forum

---

## ⚠️ Descargo de Responsabilidad

Este código es solo para fines educativos. El trading conlleva riesgos. Siempre prueba en cuentas demo antes de usar en cuentas reales.

---

**¡Tu sistema MQL4-Web está listo para usar!** 🚀
