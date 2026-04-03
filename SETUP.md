# MQL4-WEB Setup Guide

## Configuración para API Polling (Recomendado para Producción)

### Paso 1: Configurar URLs Permitidas en MT4

**CRÍTICO:** Error 5200 significa que la URL no está en la lista blanca.

1. Abre MetaTrader 4
2. Ve a **Tools → Options** (o presiona `Ctrl+O`)
3. Selecciona la pestaña **Expert Advisors**
4. Busca la sección **"Allow WebRequest for the following URLs"**
5. Haz clic en **Add** y agrega:
   ```
   https://mqweb.holancloud.com
   ```
6. Haz clic en **OK**
7. **Cierra MT4 completamente y vuelve a abrirlo**
8. Adjunta el EA

### Paso 2: Configurar Parámetros del EA

| Parámetro | Valor | Descripción |
|-----------|-------|-------------|
| `SERVER_HOST` | `mqweb.holancloud.com` | Dominio del servidor |
| `SERVER_PORT` | `443` | Puerto HTTPS |
| `USE_HTTPS` | `true` | Usar conexión segura |
| `SEND_INTERVAL` | `3` | Segundos entre envíos |
| `POLL_INTERVAL` | `3` | Segundos entre polls |
| `DEBUG_MODE` | `true` | Mostrar mensajes debug |

### Paso 3: Verificar Conexión

En los logs del EA deberías ver:
```
========================================
ApiBidirectionalEA v2.0 (WebRequest)
Server: mqweb.holancloud.com:443
HTTPS: Si
========================================
Base URL: https://mqweb.holancloud.com
Testing HTTP connection...
GET https://mqweb.holancloud.com/health
✅ HTTP test successful
```

---

## Solución de Problemas

### Error 5200: URL not allowed

**Causa:** La URL no está en la lista blanca de WebRequest.

**Solución:**
1. Tools → Options → Expert Advisors
2. Agrega `https://mqweb.holancloud.com` a "Allow WebRequest for the following URLs"
3. Click OK
4. **Cierra MT4 completamente** (no solo minimizar)
5. **Abre MT4** y adjunta el EA

**⚠️ Si sigue fallando:**
- Verifica que la URL sea exactamente: `https://mqweb.holancloud.com`
- NO agregues puerto: `https://mqweb.holancloud.com:443` ❌
- NO uses http: `http://mqweb.holancloud.com` ❌
- Ejecuta `DiagnosticWebRequest.mq4` para probar conectividad

### Error 406: Not Acceptable

**Causa:** El servidor rechaza la petición.

**Solución:** Verifica que el servidor esté funcionando en https://mqweb.holancloud.com/health

### Connection Timeout

**Causa:** Firewall o proxy bloqueando la conexión.

**Solución:**
1. Verifica tu conexión a internet
2. Prueba acceder a https://mqweb.holancloud.com desde el navegador
3. Verifica que no haya firewall corporativo bloqueando

---

## Verificar Servidor

### Health Check
```
curl https://mqweb.holancloud.com/health
```
Respuesta esperada:
```json
{"server":"running","mt4_connected":false,"pending_commands":0,"uptime":123.456}
```

### Dashboard
Abre en el navegador: https://mqweb.holancloud.com

---

## Comparación de Métodos

| Método | Puerto | Requisito MT4 | Recomendado |
|--------|--------|---------------|-------------|
| TCP Bidirectional | 8080 | "Allow DLL imports" | Solo local/dev |
| API Polling | 443 | "Allow WebRequest URLs" | **Producción** |

---

## Notas Importantes

1. **WebRequest es síncrono** - El EA se bloquea durante la petición
2. **Timeout de 5 segundos** - Ajusta si tu conexión es lenta
3. **HTTPS obligatorio** - Para producción siempre usa HTTPS
4. **Certificado SSL** - El servidor usa LetsEncrypt, válido automáticamente

---

## Soporte

- GitHub: https://github.com/Githolan/mqweb
- Issues: Reporta problemas en el repositorio
