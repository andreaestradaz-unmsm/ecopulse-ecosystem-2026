# 🌿 EcoPulse Backend — Inicio Rápido (VS Code)

Guía ultra-rápida paso a paso para levantar y probar el backend de EcoPulse desde cero utilizando **Visual Studio Code**.

---

## 🚀 Instalación y Configuración

### Paso 01: Abrir el proyecto en VS Code
1. Abre **Visual Studio Code**.
2. Selecciona **Archivo > Abrir Carpeta...** y elige:
   `d:\Descargas\ecopulse-ecosystem-2026-main\ecopulse-ecosystem-2026-main`

### Paso 02: Abrir la terminal integrada
* Abre la terminal interna presionando **`Ctrl + \``** (Control + acento grave/backtick) o ve al menú superior en **Terminal > Nueva terminal**.

### Paso 03: Crear el entorno virtual de Python
En la terminal que acabas de abrir, ejecuta:
```bash
cd backend
python -m venv venv
.\venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```
*(Dejar esta terminal abierta para mantener el backend corriendo).*

### Paso 04: Registrar un nuevo usuario en EL IP /docs
1. Despliega **`POST /api/usuarios/registro`**.
2. Da clic en **"Try it out"** (Pruébalo).
3. En la caja JSON de **Request body**, escribe:
   ```json
   {
     "username": "usuario_prueba",
     "password": "clave_segura_123"
   }
   ```
4. Da clic en el botón azul **"Execute"** (Ejecutar) y verifica que la respuesta sea `200 OK`.

### Paso 09: Autorizar el usuario (Botón Verde)
1. Ve a la parte superior de la página `/docs` y da clic al botón verde **"Authorize"** 🔓.
2. En la ventana emergente, ingresa el usuario (`usuario_prueba`) y la contraseña (`clave_segura_123`) que registraste en el Paso 08.
3. Da clic en el botón verde **"Authorize"** y luego en **"Close"**. El candado pasará a verse cerrado 🔒.

### Paso 10: Crear una Estación de Monitoreo
1. Despliega **`POST /api/estaciones`** ➡️ da clic en **"Try it out"**.
2. En el cuerpo JSON ingresa:
   ```json
   {
     "name": "Estación Sur",
     "zone": "Parque Industrial Lurín"
   }
   ```
3. Da clic en **"Execute"**. Anota o recuerda el `id` devuelto en la respuesta (por ejemplo, `id: 2`).

### Paso 11: Registrar lecturas de Emisiones
1. Despliega **`POST /api/emisiones`** ➡️ da clic en **"Try it out"**.
2. Ingresa el JSON enlazándolo al ID de tu estación (ej. `station_id: 2`):
   ```json
   {
     "station_id": 2,
     "pm25": 38.5,
     "co2": 402.1,
     "nox": 29.4
   }
   ```
3. Da clic en **"Execute"** para enviar la telemetría.

### Paso 12: Verificar datos para el simulador Godot (Público)
1. Despliega **`GET /app/datos_ambientales`** ➡️ da clic en **"Try it out"** ➡️ da clic en **"Execute"**.
2. Recibirás un JSON con la métrica PM2.5 procesada lista para alimentar el simulador sin requerir token de autenticación.
