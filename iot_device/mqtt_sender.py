# Simulador inteligente de sensores IoT — genera telemetría realista y la publica por MQTT
import time
import random
import json
import math
import requests
import paho.mqtt.client as mqtt

# Broker MQTT público de HiveMQ
BROKER = "broker.hivemq.com"
PORT = 1883
# Tópico con el ID de la estación como variable dinámica
TOPIC_BASE = "ecopulse/smat/estaciones/{}/emisiones"

# URLs del backend para autenticación y consulta de estaciones activas
TOKEN_URL = "http://127.0.0.1:8000/api/usuarios/login"
ESTACIONES_URL = "http://127.0.0.1:8000/api/estaciones"

# Credenciales del administrador para obtener el JWT
USUARIO = "admin"
PASSWORD = "admin"
TOKEN_ACTUAL = None


# Obtiene un token JWT del backend para poder consultar la lista de estaciones
def obtener_token():
    global TOKEN_ACTUAL
    try:
        respuesta = requests.post(TOKEN_URL, data={"username": USUARIO, "password": PASSWORD})
        if respuesta.status_code == 200:
            TOKEN_ACTUAL = respuesta.json().get("access_token")
            return True
        print("[⚠️] Error de autenticación para listar estaciones.")
        return False
    except Exception as e:
        print(f"[❌] Error conectando al login del Backend: {e}")
        return False


# Consulta la API para obtener los IDs de estaciones activas.
# Permite detectar en caliente nuevas estaciones agregadas desde Flutter.
def consultar_estaciones_backend():
    """Consulta la API de FastAPI para ver qué sensores existen actualmente"""
    global TOKEN_ACTUAL
    if not TOKEN_ACTUAL and not obtener_token():
        return []

    headers = {"Authorization": f"Bearer {TOKEN_ACTUAL}"}
    try:
        res = requests.get(ESTACIONES_URL, headers=headers)
        if res.status_code == 401:
            # Token expirado: renueva y reintenta la consulta
            obtener_token()
            headers["Authorization"] = f"Bearer {TOKEN_ACTUAL}"
            res = requests.get(ESTACIONES_URL, headers=headers)

        if res.status_code == 200:
            estaciones_json = res.json()
            ids = [int(estacion["id"]) for estacion in estaciones_json if "id" in estacion]
            return sorted(ids)
        else:
            print(f"[⚠️] Error al obtener estaciones ({res.status_code}): {res.text}")
            return []
    except Exception as e:
        print(f"[❌] Error de conexión al consultar estaciones: {e}")
        return []


# Genera valores sintéticos de PM2.5, CO2 y NOx usando funciones senoidales.
# El desfase por station_id hace que cada sensor tenga un ciclo de contaminación distinto.
def generar_telemetria(station_id):
    desfase = station_id * 5.0
    t = (time.time() / 5.0) + desfase

    # Oscilación sinusoidal con ruido aleatorio para simular variaciones reales
    pm25_actual = max(2.0, 25.0 + math.sin(t) * 25.0 + random.uniform(-2.0, 2.0))
    co2_actual = max(400.0, 450.0 + math.cos(t * 0.8) * 50.0 + random.uniform(-5.0, 5.0))
    nox_actual = 30.0 + math.sin(t * 1.2) * 20.0 + random.uniform(-1.0, 1.0)

    # Clasifica el estado del aire según los umbrales de PM2.5 de la OMS
    estado = "MALO (ALERTA PM2.5)" if pm25_actual > 35.0 else ("MODERADO" if pm25_actual > 12.0 else "BIEN (Saludable)")

    payload = {
        "station_id": station_id,
        "pm25": round(pm25_actual, 2),
        "co2": round(co2_actual, 2),
        "nox": round(nox_actual, 2),
        "estado_aire": estado
    }
    return payload, estado


# Conecta al broker MQTT y entra en el bucle principal de simulación.
# Cada 5 segundos publica la telemetría de la próxima estación en el ciclo.
# Al inicio de cada ronda completa, re-sincroniza la lista de estaciones con el backend.
def iniciar_sensor():
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1)
    print(f"Conectando al Broker de HiveMQ: {BROKER}...")
    client.connect(BROKER, PORT, 60)
    client.loop_start()
    print("¡Sensor IoT EcoPulse Inteligente Iniciado!")

    print("\n🔍 Sincronizando lista inicial de estaciones con el Backend...")
    estaciones_activas = consultar_estaciones_backend()
    print(f"📌 Estaciones detectadas al arrancar: {estaciones_activas}")

    # Índice para iterar en orden por las estaciones de forma circular
    indice_actual = 0

    try:
        while True:
            # Al comenzar un nuevo ciclo, re-consulta el backend por si hay estaciones nuevas
            if indice_actual == 0:
                print("\n🔄 Revisando si se agregaron nuevos sensores desde Flutter...")
                lista_nueva = consultar_estaciones_backend()
                if lista_nueva:
                    estaciones_activas = lista_nueva
                print(f"📋 Ciclo actual de simulación: {estaciones_activas}")

            if not estaciones_activas:
                print("[⚠️] No hay estaciones registradas en el sistema. Esperando...")
                time.sleep(5)
                indice_actual = 0
                continue

            if indice_actual >= len(estaciones_activas):
                indice_actual = 0
                continue

            id_sensor = estaciones_activas[indice_actual]

            # Genera y publica la telemetría de esta estación en su tópico específico
            datos, estado = generar_telemetria(id_sensor)
            json_data = json.dumps(datos)

            topico_especifico = TOPIC_BASE.format(id_sensor)
            client.publish(topico_especifico, json_data)

            print("=========================================================")
            print(f"[MQTT SEND] 📡 SENSOR ACTIVO: ID {id_sensor} | {estado}")
            print(f"Valores -> PM2.5: {datos['pm25']} µg/m³ | CO2: {datos['co2']} ppm")

            # Avanza al siguiente sensor del ciclo
            indice_actual = (indice_actual + 1) % len(estaciones_activas)

            time.sleep(5)

    except KeyboardInterrupt:
        print("\nSimulador detenido.")
        client.disconnect()


if __name__ == "__main__":
    iniciar_sensor()
