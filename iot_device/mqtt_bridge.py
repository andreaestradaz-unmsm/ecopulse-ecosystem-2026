import json
import time
import requests
import paho.mqtt.client as mqtt

BROKER = "broker.hivemq.com"
PORT = 1883
TOPIC = "ecopulse/smat/estaciones/+/emisiones"

API_URL = "http://127.0.0.1:8000/api/emisiones"
TOKEN_URL = "http://127.0.0.1:8000/api/usuarios/login"

USUARIO = "admin"
PASSWORD = "admin"
TOKEN_ACTUAL = None

cache_estaciones = {}

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

def enviar_al_backend(datos):
    global TOKEN_ACTUAL
    if not TOKEN_ACTUAL and not obtener_token():
        return
    
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {TOKEN_ACTUAL}"
    }
    
    payload_backend = {
        "station_id": datos.get("station_id", 1),
        "pm25": datos.get("pm25"),
        "co2": datos.get("co2"),
        "nox": datos.get("nox")
    }
    
    try:
        res = requests.post(API_URL, json=payload_backend, headers=headers)
        if res.status_code == 401:
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

def evaluar_filtro_ingesta(datos):
    station_id = datos.get("station_id", 1)
    pm25_nuevo = datos.get("pm25")
    co2_nuevo = datos.get("co2")
    nox_nuevo = datos.get("nox")
    tiempo_actual = time.time()

    if station_id not in cache_estaciones:
        print(f"[FILTRO] 🆕 Primera lectura de Estación {station_id}. Inicializando caché.")
        cache_estaciones[station_id] = {
            "pm25": pm25_nuevo, "co2": co2_nuevo, "nox": nox_nuevo, "last_time": tiempo_actual
        }
        return True

    viejo = cache_estaciones[station_id]
    tiempo_diff = tiempo_actual - viejo["last_time"]

    var_pm25 = abs(pm25_nuevo - viejo["pm25"]) / viejo["pm25"]
    var_co2 = abs(co2_nuevo - viejo["co2"]) / viejo["co2"]
    var_nox = abs(nox_nuevo - viejo["nox"]) / viejo["nox"]

    print(f"--- Evaluando Filtro para Estación {station_id} (Transcurrido: {int(tiempo_diff)}s) ---")
    print(f" Variación PM2.5: {var_pm25:.1%} | CO2: {var_co2:.1%} | NOx: {var_nox:.1%}")

    if tiempo_diff > 60.0:
        print("[FILTRO] ⏱️ Alerta de Tiempo (Heartbeat > 60s). Forzando inserción de datos.")
        cache_estaciones[station_id] = {
            "pm25": pm25_nuevo, "co2": co2_nuevo, "nox": nox_nuevo, "last_time": tiempo_actual
        }
        return True

    if var_pm25 > 0.05 or var_co2 > 0.05 or var_nox > 0.05:
        print("[FILTRO] 🚀 Cambio mayor al 5% detectado. Actualizando base de datos.")
        cache_estaciones[station_id] = {
            "pm25": pm25_nuevo, "co2": co2_nuevo, "nox": nox_nuevo, "last_time": tiempo_actual
        }
        return True

    print("❌ [FILTRO BLOQUEADO] Datos redundantes ignorados para evitar saturación.")
    return False

def on_connect(client, userdata, flags, rc):
    print(f"[BRIDGE] Conectado exitosamente al Broker MQTT.")
    client.subscribe(TOPIC)
    obtener_token()

def on_message(client, userdata, msg):
    try:
        datos = json.loads(msg.payload.decode('utf-8'))
        
        if datos.get("pm25", 0) > 35.0:
            print("\n⚠️ [ALERTA] Estado Crítico de Calidad del Aire!")
        else:
            print("\n🍃 [INFO] Estado Estable de Calidad del Aire.")

        debe_enviar = evaluar_filtro_ingesta(datos)
        
        if debe_enviar:
            enviar_al_backend(datos)
            
    except json.JSONDecodeError:
        print("[BRIDGE ERROR] Mensaje JSON corrupto.")

def iniciar_bridge():
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1)
    client.on_connect = on_connect
    client.on_message = on_message
    client.connect(BROKER, PORT, 60)
    client.loop_forever()

if __name__ == "__main__":
    iniciar_bridge()
