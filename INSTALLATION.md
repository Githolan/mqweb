# Guía de Instalación - MQL4 Web Communication

Esta guía explica paso a paso cómo configurar la comunicación entre MQL4 y un servidor web.

---

## 📋 Tabla de Contenidos

1. [Requisitos Previos](#requisitos-previos)
2. [Instalación de mql_requests](#instalación-de-mql_requests)
3. [Configuración de MetaTrader 4](#configuración-de-metatrader-4)
4. [Instalación del Servidor](#instalación-del-servidor)
5. [Probar la Conexión](#probar-la-conexión)
6. [Solución de Problemas](#solución-de-problemas)

---

## 📦 Requisitos Previos

- **MetaTrader 4** instalado
- **Node.js** (v14 o superior) - [Descargar aquí](https://nodejs.org/)
- **Editor de texto** (VS Code, Notepad++, etc.)
- **Conexión a internet**

---

## 🔧 Instalación de mql_requests

### Paso 1: Descargar la biblioteca

Ve a GitHub y descarga la biblioteca:
```
https://github.com/vivazzi/mql_requests/archive/refs/heads/main.zip
```

O clona el repositorio:
```bash
git clone https://github.com/vivazzi/mql_requests.git
```

### Paso 2: Copiar archivos a MT4

1. Abre tu terminal MT4
2. Ve a **File → Open Data Folder**
3. Navega a la carpeta `MQL4/Include/`
4. Si no existe la carpeta `requests`, créala
5. Copia **TODOS** los archivos de la biblioteca:

```
mql_requests/
└── Include/
    └── requests/
        ├── requests.mqh          ← Copiar este
        └── classes/
            ├── request_data.mqh  ← Copiar este
            ├── response.mqh      ← Copiar este
            └── _url_parts.mqh    ← Copiar este
```

La estructura final en tu MT4 debe ser:
```
<MQL4>/Include/requests/requests.mqh
<MQL4>/Include/requests/classes/request_data.mqh
<MQL4>/Include/requests/classes/response.mqh
<MQL4>/Include/requests/classes/_url_parts.mqh
```

### Paso 3: Verificar instalación

Abre MetaEditor (F4 en MT4) y verifica que puedas ver la carpeta `requests` en:
```
Include → requests → requests.mqh
```

---

## ⚙️ Configuración de MetaTrader 4

### Paso 1: Permitir DLLs

1. En MT4, ve a **Tools → Options → Expert Advisors**
2. Marca ✅ **"Allow DLL imports"**
3. Marca ✅ **"Allow external experts imports"**
4. Click en **OK**

### Paso 2: Configurar WebRequest (si usas WebRequest nativo)

1. En la misma pantalla, click en el botón **"WebRequest"**
2. Agrega tu URL del servidor:
   ```
   https://your-api.com
   ```
3. Click en **OK**

> **Nota:** La biblioteca mql_requests usa WinINET directamente, por lo que puede que no necesites configurar WebRequest. Pero se recomienda hacerlo por seguridad.

---

## 🖥️ Instalación del Servidor

### Paso 1: Crear carpeta del proyecto

```bash
mkdir mql4-server
cd mql4-server
```

### Paso 2: Copiar archivos

Copia los siguientes archivos de este proyecto:
- `server.js`
- `package.json`

### Paso 3: Instalar dependencias

```bash
npm install
```

Esto instalará:
- `express` - Servidor web
- `body-parser` - Para parsear JSON
- `cors` - Para permitir peticiones cross-origin

### Paso 4: Iniciar el servidor

```bash
npm start
```

Deberías ver:
```
╔════════════════════════════════════════╗
║   MQL4 Web Receiver Server Iniciado    ║
╚════════════════════════════════════════╝
🚀 Servidor corriendo en http://localhost:3000
✅ Listo para recibir datos de MQL4
```

### Paso 5: Verificar que funciona

Abre tu navegador en:
```
http://localhost:3000
```

Deberías ver la página del servidor funcionando.

---

## 🧪 Probar la Conexión

### Opción 1: Usar el EA de prueba

1. Copia `WebSenderEA.mq4` a tu carpeta `MQL4/Experts/`
2. En MetaEditor, abre el archivo
3. Cambia la URL del servidor:
   ```mql4
   input string SERVER_URL = "http://localhost:3000/receive-data";
   ```
4. Compila (F7)
5. En MT4, arrastra el EA a un gráfico
6. Verifica el log de "Experts" para ver si se conectó

### Opción 2: Usar cURL

```bash
curl -X POST http://localhost:3000/receive-data \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "symbol=EURUSD&bid=1.0850&ask=1.0851&test=true"
```

Deberías ver respuesta del servidor:
```json
{
  "success": true,
  "message": "Datos recibidos correctamente"
}
```

---

## 🔧 Solución de Problemas

### Problema: "DLL function call failed not allowed"

**Solución:**
1. Tools → Options → Expert Advisors
2. ✅ Marca "Allow DLL imports"
3. Reinicia MT4

### Problema: "Error InternetOpenUrlW"

**Solución:**
1. Verifica que tienes conexión a internet
2. Desactiva temporalmente el firewall/antivirus
3. Ejecuta MT4 como administrador

### Problema: "Error HttpSendRequestW"

**Solución:**
1. Verifica que la URL del servidor es correcta
2. Verifica que el servidor esté funcionando
3. Prueba con `http://` en lugar de `https://`

### Problema: SSL/HTTPS errors

**Solución:**
La biblioteca mql_requests ya incluye código para ignorar errores de certificado SSL. Si persiste:
1. Usa `http://` para pruebas locales
2. Para producción, obtén un certificado SSL válido

### Problema: El EA no compila

**Solución:**
1. Verifica que todos los archivos de mql_requests estén en su lugar
2. En MetaEditor, ve a `Include → requests` y verifica que los archivos existen
3. Si falta algún archivo, descárgalo nuevamente de GitHub

### Problema: Error 12045 (ERROR_INTERNET_INVALID_CA)

**Solución:**
Este error es manejado automáticamente por mql_requests. La biblioteca:
```mql4
// Ya incluye código para ignorar errores de certificado
if (err == ERROR_INTERNET_INVALID_CA) {
    dwFlags |= SECURITY_FLAG_IGNORE_UNKNOWN_CA;
    InternetSetOptionW(h_request, INTERNET_OPTION_SECURITY_FLAGS, dwFlags, sizeof(dwFlags));
}
```

---

## 📝 Estructura Final

Después de completar la instalación, tu estructura debe ser:

```
MQL4/
├── Experts/
│   └── WebSenderEA.mq4          ← Tu EA
├── Include/
│   └── requests/
│       ├── requests.mqh
│       └── classes/
│           ├── request_data.mqh
│           ├── response.mqh
│           └── _url_parts.mqh
└── Libraries/

mql4-server/
├── server.js                     ← Servidor Node.js
├── package.json
├── node_modules/
└── mt4_data.log                  ← Logs de datos recibidos
```

---

## ✅ Checklist Final

Antes de usar en producción, verifica:

- [ ] mql_requests instalado correctamente
- [ ] DLLs permitidos en MT4
- [ ] Servidor Node.js funcionando
- [ ] EA compila sin errores
- [ ] Prueba de conexión exitosa
- [ ] Logs de datos recibidos visibles

---

## 🚀 Siguiente Paso

Una vez configurado todo, puedes:

1. Personalizar el EA (`WebSenderEA.mq4`) con tus propios datos
2. Modificar el servidor (`server.js`) para procesar los datos
3. Conectar a una base de datos
4. Crear tu propia API o dashboard

¡Tu sistema MQL4-Web está listo!
