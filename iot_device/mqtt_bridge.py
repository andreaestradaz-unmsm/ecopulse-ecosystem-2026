# Puente MQTT → API REST: recibe mensajes de los sensores y los persiste en la BD
import json
import time
import requests
import paho.mqtt.client as mqtt

# Broker MQTT público de HiveMQ (sin autenticación)
BROKER = "broker.hivemq.com"
PORT = 1883
# Tópico comodín: escucha a TODAS las estaciones registradas
TOPIC = "ecopulse/smat/estaciones/+/emisiones"

# URLs del backend FastAPI local
API_URL = "http://127.0.0.1:8000/api/emisiones"
TOKEN_URL = "http://127.0.0.1:8000/api/usuarios/login"

# Credenciales del usuario administrador para autenticarse con la API
USUARIO = "admin"
PASSWORD = "admin"
TOKEN_ACTUAL = None

# Caché en memoria: almacena el último dato recibido por estación para aplicar el filtro
cache_estaciones = {}


# Obtiene un nuevo token JWT del backend; se llama al arrancar y cuando el token expira
def obtener_token():
    global TOKEN_ACTUAL
    try:
        respuesta = requests.post(TOKEN_URL, data={"username": USUARIO, "password": PASSWORD})
        if respuesta.status_code == 200:
            TOKEN_ACTUAL = respuesta.json().get("access_token")
            print("[BRIDGE] ✅ Token de acceso obtenido del Backend.")
            return True
        return False
    except Exception as e:
        print(f"[BRIDGE] ❌ Error conectando al Backend FastAPI: {e}")
        return False


# Envía los datos de una emisión al endpoint POST /api/emisiones con el token JWT.
# Si el token expiró (401), lo renueva automáticamente y reintenta el envío.
def enviar_al_backend(datos):
    global TOKEN_ACTUAL
    if not TOKEN_ACTUAL and not obtener_token():
        return

    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {TOKEN_ACTUAL}"
    }

    # Prepara el payload con los campos que espera el endpoint
    payload_backend = {
        "station_id": datos.get("station_id", 1),
        "pm25": datos.get("pm25"),
        "co2": datos.get("co2"),
        "nox": datos.get("nox")
    }

    try:
        res = requests.post(API_URL, json=payload_backend, headers=headers)
        if res.status_code == 401:
            # Token expirado: renueva y reintenta
            print("[BRIDGE] Token expirado, renovando...")
            obtener_token()
            headers["Authorization"] = f"Bearer {TOKEN_ACTUAL}"
            res = requests.post(API_URL, json=payload_backend, headers=headers)

        if res.status_code in [200, 201]:
            print(f"[DATABASE OK] 💾 Guardado en SQLite para Estación {payload_backend['station_id']}.")
        else:
            print(f"[BACKEND ERROR] {res.status_code}: {res.text}")
    except Exception as e:
        print(f"[BACKEND ERROR] Excepción: {e}")


# Filtro inteligente de ingesta: decide si vale la pena guardar una nueva lectura.
# Evita saturar la BD con datos repetitivos. Persiste sólo si:
#   - Es la primera lectura de esa estación.
#   - Han pasado más de 60 segundos desde la última inserción (heartbeat).
#   - Al menos uno de los contaminantes cambió más del 5% respecto al valor anterior.
def evaluar_filtro_ingesta(datos):
    station_id = datos.get("station_id", 1)
    pm25_nuevo = datos.get("pm25")
    co2_nuevo = datos.get("co2")
    nox_nuevo = datos.get("nox")
    tiempo_actual = time.time()

    # Primera vez que se recibe un dato de esta estación: inicializa la caché
    if station_id not in cache_estaciones:
        print(f"[FILTRO] 🆕 Primera lectura de Estación {station_id}. Inicializando caché.")
        cache_estaciones[station_id] = {
            "pm25": pm25_nuevo, "co2": co2_nuevo, "nox": nox_nuevo, "last_time": tiempo_actual
        }
        return True

    viejo = cache_estaciones[station_id]
    tiempo_diff = tiempo_actual - viejo["last_time"]

    # Calcula la variación porcentual de cada contaminante respecto al valor anterior
    var_pm25 = abs(pm25_nuevo - viejo["pm25"]) / viejo["pm25"]
    var_co2 = abs(co2_nuevo - viejo["co2"]) / viejo["co2"]
    var_nox = abs(nox_nuevo - viejo["nox"]) / viejo["nox"]

    print(f"--- Evaluando Filtro para Estación {station_id} (Transcurrido: {int(tiempo_diff)}s) ---")
    print(f" Variación PM2.5: {var_pm25:.1%} | CO2: {var_co2:.1%} | NOx: {var_nox:.1%}")

    # Heartbeat: fuerza una inserción si pasó más de 1 minuto aunque los datos no cambien
    if tiempo_diff > 60.0:
        print("[FILTRO] ⏱️ Alerta de Tiempo (Heartbeat > 60s). Forzando inserción de datos.")
        cache_estaciones[station_id] = {
            "pm25": pm25_nuevo, "co2": co2_nuevo, "nox": nox_nuevo, "last_time": tiempo_actual
        }
        return True

    # Cambio significativo: algún contaminante varió más del 5%
    if var_pm25 > 0.05 or var_co2 > 0.05 or var_nox > 0.05:
        print("[FILTRO] 🚀 Cambio mayor al 5% detectado. Actualizando base de datos.")
        cache_estaciones[station_id] = {
            "pm25": pm25_nuevo, "co2": co2_nuevo, "nox": nox_nuevo, "last_time": tiempo_actual
        }
        return True

    # Datos redundantes: se descartan para no saturar la BD
    print("❌ [FILTRO BLOQUEADO] Datos redundantes ignorados para evitar saturación.")
    return False


# Callback ejecutado al conectarse exitosamente al broker MQTT
def on_connect(client, userdata, flags, rc):
    print(f"[BRIDGE] Conectado exitosamente al Broker MQTT.")
    client.subscribe(TOPIC)   # Se suscribe al tópico de todas las estaciones
    obtener_token()           # Obtiene el JWT para poder enviar al backend


# Callback ejecutado al recibir un mensaje MQTT de cualquier estación
def on_message(client, userdata, msg):
    try:
        datos = json.loads(msg.payload.decode('utf-8'))

        # Alerta de calidad del aire según el umbral de la OMS (35 µg/m³)
        if datos.get("pm25", 0) > 35.0:
            print("\n⚠️ [ALERTA] Estado Crítico de Calidad del Aire!")
        else:
            print("\n🍃 [INFO] Estado Estable de Calidad del Aire.")

        # Aplica el filtro antes de decidir si persistir el dato
        debe_enviar = evaluar_filtro_ingesta(datos)

        if debe_enviar:
            enviar_al_backend(datos)

    except json.JSONDecodeError:
        print("[BRIDGE ERROR] Mensaje JSON corrupto.")


# Inicializa el cliente MQTT, asigna los callbacks y entra en el bucle de escucha
def iniciar_bridge():
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1)
    client.on_connect = on_connect
    client.on_message = on_message
    client.connect(BROKER, PORT, 60)
    # loop_forever() bloquea el hilo y mantiene activa la escucha de mensajes
    client.loop_forever()


if __name__ == "__main__":
    iniciar_bridge()
