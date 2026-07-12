# 🌿 EcoPulse Ecosystem — Guía de Ejecución

Esta guía detalla los pasos exactos para inicializar todo el ecosistema (Backend, IoT, Móvil y Godot) desde cero. Las instrucciones incluyen comandos para **Windows** y **Linux/macOS**.

---

## 1. Backend (FastAPI + SQLite)
El backend centraliza los datos, maneja la autenticación y expone la API HTTP.

### Configuración e Instalación
Abre una terminal, navega a la carpeta `backend` y crea el entorno virtual:

**Windows:**
```bash
cd backend
python -m venv venv
.\venv\Scripts\activate
pip install -r requirements.txt
```

**Linux/macOS:**
```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Inicializar Datos y Arrancar el Servidor
Primero, inicializa la base de datos (esto crea el usuario `admin` con contraseña `admin` y la estación por defecto). Luego, arranca el servidor.

**Comandos (Ambos SO):**
```bash
python -m app.seed  #opcional se puede hacer manual por el flutter
uvicorn app.main:app --reload
```
*(Mantén esta terminal abierta)*

---

## 2. Dispositivo IoT (Sensor y Bridge MQTT)
Simula un hardware físico que envía telemetría de aire vía el broker HiveMQ y un Bridge que atrapa los datos y los inserta en tu Backend.

### Configuración e Instalación
Abre una **nueva terminal**, navega a `iot_device` y prepara su entorno:

**Windows:**
```bash
cd iot_device
python -m venv venv
.\venv\Scripts\activate
pip install paho-mqtt requests
```

**Linux/macOS:**
```bash
cd iot_device
python3 -m venv venv
source venv/bin/activate
pip install paho-mqtt requests
```

### Ejecutar el Ecosistema IoT
Necesitas **dos terminales** para IoT (ambas con el entorno virtual activado).

**Terminal A (Bridge MQTT a HTTP):**
```bash
# Windows
python mqtt_bridge.py

# Linux/macOS
python3 mqtt_bridge.py
```
*(Este script filtra las variaciones, descarta datos basura y envía solo los cambios válidos a la base de datos)*

**Terminal B (Emisor de Datos):**
```bash
# Windows
python mqtt_sender.py

# Linux/macOS
python3 mqtt_sender.py
```
*(Este script simula los datos de contaminación ambiental variando cíclicamente cada 5 segundos)*

---

## 3. Aplicación Móvil (Flutter)
La app móvil permite a los ciudadanos conectarse al backend y ver los niveles de contaminación en tiempo real.

Abre una **nueva terminal** en la carpeta `mobile`:

**Comandos (Ambos SO):**
```bash
cd mobile
flutter pub get
flutter run
```
*(Selecciona tu dispositivo web, Windows o emulador cuando te lo pregunte la consola)*

---

## 4. Gemelo Digital (Godot Engine)
La simulación 3D/2D visualiza la contaminación como una nube volumétrica dinámica que cambia de color y densidad en tiempo real.

1. Abre **Godot Engine**.
2. Dale a **Importar** y selecciona el archivo `project.godot` dentro de la carpeta `simulation_godot`.
3. Una vez abierto el editor, presiona la tecla **F5** (o el botón de Play arriba a la derecha).
4. El simulador se logueará automáticamente al backend, descargará el nivel de PM2.5 y **sincronizará el color de la nube (Verde, Naranja o Rojo)**. Seguirá actualizándose solo cada 5 segundos.

---
🚀 **¡Felicidades! Todo el ecosistema (Sensores, BD, App y Simulador) está ahora sincronizado y en funcionamiento.**
