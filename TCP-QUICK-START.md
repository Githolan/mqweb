# Guía Rápida - Sistema TCP Bidireccional MQL4-Web

## 🚀 Inicio Rápido (5 minutos)

### Paso 1: Iniciar el Servidor Node.js

```bash
cd MQL4-WEB
npm install
npm run start:tcp
```

Deberías ver:
```
╔═══════════════════════════════════════════════════════════╗
║         MT4 TCP Server Iniciado                          ║
╚═══════════════════════════════════════════════════════════╝
🚀 Servidor TCP escuchando en puerto 8080
🌐 Dashboard disponible en http://localhost:3001
✅ Servidor listo para recibir conexiones de MT4
```

### Paso 2: Abrir el Dashboard

Abre tu navegador en: **http://localhost:3000**

Verás "⚫ Desconectado" esperando que MT4 se conecte.

### Paso 3: Configurar MT4

1. Abre **MetaEditor** (F4 en MT4)
2. Abre el archivo `TcpBidirectionalEA.mq4`
3. Compila (F7)
4. En MT4, arrastra el EA a un gráfico
5. Asegúrate de permitir DLL imports si pregunta

### Paso 4: Verificar Conexión

En el **log de Experts** en MT4 deberías ver:
```
✅ Conectado al servidor TCP 127.0.0.1:9000
```

En el **dashboard web** verás "🟢 Conectado" con datos de mercado.

---

## 💬 Enviar Comandos a MT4

En el dashboard web:

1. Escribe un mensaje en el campo de texto
2. Click "Enviar Alerta"
3. MT4 mostrará un Alert() con tu mensaje

**Mensajes rápidos:**
- Click "¡Hola!" - Envía saludo
- Click "Revisar Ops" - Pide revisar operaciones
- Click "Target" - Avisa de precio objetivo
- Click "SL Cercano" - Avisa de Stop Loss cercano

---

## 📊 Datos Enviados por MT4

El EA envía automáticamente cada 3 segundos:

| Dato | Descripción |
|------|-------------|
| Symbol | Símbolo del gráfico (ej: EURUSD) |
| Bid | Precio Bid actual |
| Ask | Precio Ask actual |
| Spread | Spread en puntos |
| Balance | Balance de la cuenta |
| Equity | Equity actual |
| Profit | Profit flotante |
| Margin | Margin usado |

---

## 🔧 Configuración del EA

Parámetros configurables en MT4:

| Parámetro | Default | Descripción |
|-----------|---------|-------------|
| SERVER_HOST | 127.0.0.1 | Dirección del servidor |
| SERVER_PORT | 9000 | Puerto TCP |
| RECONNECT_SECONDS | 10 | Segundos entre reintentos |
| SEND_INTERVAL | 3 | Segundos entre envíos de datos |
| DEBUG_MODE | true | Mostrar mensajes de debug |

---

## 🌐 Para Usar en Internet

### Desde Internet hacia tu red local

Si quieres acceder al dashboard desde internet:

1. **Configurar puerto forwarding en tu router:**
   - Puerto externo: 3000 → Puerto interno: [tu IP]:3000

2. **Obtener tu IP pública:**
   ```bash
   # En Windows
   curl ifconfig.me
   ```

3. **Actualizar SERVER_HOST en MT4:**
   - Si el servidor está en otra máquina, usar la IP de esa máquina
   - Ejemplo: `192.168.1.100` (red local) o tu IP pública

### Desde MT4 hacia servidor en internet

Si el servidor Node.js está en internet (VPS, cloud, etc.):

1. Cambiar `SERVER_HOST` en MT4 a la dirección IP o dominio del servidor
2. Asegurar que el firewall del servidor permita puerto 9000 TCP

```bash
# En Linux (VPS)
sudo ufw allow 9000/tcp
```

---

## 🐛 Solución de Problemas

### MT4 no se conecta

**Síntoma:** En log de MT4: "❌ connect() failed"

**Solución:**
1. Verificar que el servidor Node.js está corriendo
2. Verificar que el puerto 9000 no esté en uso
   ```bash
   # Windows
   netstat -an | findstr 9000
   ```
3. Desactivar firewall temporalmente
4. Asegurarse que MT4 tiene permitido usar DLLs

### Dashboard muestra "Desconectado"

**Síntoma:** Estado ⚫ Desconectado en web

**Solución:**
1. Verificar que MT4 está corriendo y el EA está adjunto a un gráfico
2. Verificar log de Experts en MT4
3. Verificar que el EA muestra "✅ Conectado"

### No se reciben datos de mercado

**Síntoma:** Dashboard conectado pero datos "-"

**Solución:**
1. Verificar que hay movimiento en el mercado (OnTick se ejecuta)
2. Aumentar `SEND_INTERVAL` si el mercado está lento
3. Verificar `DEBUG_MODE` en EA para ver logs

### Comandos no llegan a MT4

**Síntoma:** Click "Enviar Alerta" pero no aparece en MT4

**Solución:**
1. Verificar que MT4 está conectado (dashboard verde)
2. Verificar logs del servidor Node.js
3. Verificar que el EA tiene permisos para mostrar Alert()

---

## 📝 Arquitectura

```
MT4 (EA)                    Node.js                   Web
┌────────┐                  ┌────────┐                ┌──────┐
│ ws2_32 │ ←─ TCP 9000 ───→│ TCP    │ ←─ HTTP 3000 ─→│ HTML │
│ .dll   │                  │ Server │                │      │
└────────┘                  └────────┘                └──────┘
     ↓                           ↓                         ↓
  Bypass                       Bridge               Dashboard
  Sandbox                     TCP+HTTP                 Web
```

---

## ⚡ Ventajas del TCP vs HTTP

| Característica | HTTP/WebRequest | TCP WinSock |
|----------------|-----------------|-------------|
| Requiere "webs confiables" | ✅ Sí | ❌ No |
| Sandbox MQL4 filtra | ✅ Sí | ❌ No |
| Funciona con cualquier broker | ❌ No | ✅ Sí |
| Conexión persistente | ❌ No | ✅ Sí |
| Bidiireccional real | ❌ No | ✅ Sí |

---

## 📁 Archivos del Sistema

| Archivo | Descripción |
|---------|-------------|
| `Examples/TcpBidirectionalEA.mq4` | EA MQL4 con socket TCP |
| `Examples/tcp-server.js` | Servidor Node.js TCP + HTTP |
| `Examples/dashboard.html` | Dashboard web |
| `package.json` | Dependencias npm |

---

## 🎯 Comandos Disponibles

| Comando | Acción en MT4 |
|---------|---------------|
| `alert` | Muestra Alert() con mensaje |
| `log` | Muestra mensaje en log |
| `ping` | Heartbeat (automático) |
| `pong` | Respuesta a ping (automático) |

---

## ✅ Checklist de Verificación

Antes de usar en producción:

- [ ] Servidor Node.js inicia correctamente
- [ ] Dashboard abre en http://localhost:3000
- [ ] EA compila sin errores en MetaEditor
- [ ] EA se conecta al servidor (log MT4 muestra "✅ Conectado")
- [ ] Dashboard muestra "🟢 Conectado"
- [ ] Datos de mercado se actualizan
- [ ] Enviar alerta funciona
- [ ] Reconexión automática funciona (parar/arrancar servidor)

---

## 🚀 Próximos Pasos

Una vez funcionando:

1. **Personalizar el dashboard** con tu marca
2. **Agregar más comandos** según necesites
3. **Conectar a base de datos** para guardar histórico
4. **Desplegar en VPS** para acceso 24/7
5. **Agregar autenticación** para múltiples usuarios

---

## 💡 Tips

- El EA se reconecta automáticamente cada 10 segundos si pierde conexión
- Los comandos se encolan si MT4 no está conectado
- El servidor puede manejar múltiples clientes MT4 simultáneos
- El heartbeat mantiene la conexión activa

¡Tu sistema está listo para usar! 🎉
