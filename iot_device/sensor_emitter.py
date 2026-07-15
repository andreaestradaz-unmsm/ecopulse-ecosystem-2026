# Sensor IoT básico — envía datos directamente a la API REST sin pasar por MQTT
import requests
import time
import random

# Endpoints del backend FastAPI
API_URL = "http://127.0.0.1:8000/api/emisiones"
TOKEN_URL = "http://127.0.0.1:8000/api/usuarios/login"

# ID de la estación que este sensor emula (estación 1 por defecto)
STATION_ID = 1

# Credenciales del administrador para obtener el JWT de autenticación
USUARIO = "admin"
PASSWORD = "admin"


# Obtiene el token JWT necesario para autorizar el POST de emisiones
def obtener_token():
    try:
        respuesta = requests.post(TOKEN_URL, data={"username": USUARIO, "password": PASSWORD})
        if respuesta.status_code == 200:
            return respuesta.json().get("access_token")
        else:
            print(f"[!] Error de autenticación: Verifica que el usuario '{USUARIO}' exista.")
    except Exception as e:
        print(f"[!] Error conectando al servidor para login: {e}")
    return None


# Bucle principal del sensor: genera y envía lecturas aleatorias cada N segundos.
# Si PM2.5 supera el umbral crítico (35 µg/m³), acelera el envío a 2 segundos.
def enviar_telemetria():
    print("=========================================================")
    print(" 🏭 Iniciando Sensor IoT - EcoPulse (Gemelo Digital) ")
    print("=========================================================")

    # Autenticación inicial: si falla, no se puede enviar datos
    token = obtener_token()
    if not token:
        print("Deteniendo sensor por falta de credenciales.")
        return

    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}"
    }

    while True:
        # Genera valores aleatorios dentro de rangos realistas para cada contaminante
        pm25_val = round(random.uniform(5.0, 50.0), 2)
        co2_val = round(random.uniform(400.0, 900.0), 2)
        nox_val = round(random.uniform(20.0, 80.0), 2)

        payload = {
            "station_id": STATION_ID,
            "pm25": pm25_val,
            "co2": co2_val,
            "nox": nox_val
        }

        try:
            respuesta = requests.post(API_URL, json=payload, headers=headers)
            if respuesta.status_code in [200, 201]:
                print(f"[OK] PM2.5: {pm25_val:>5} µg/m³ | CO2: {co2_val:>6} ppm | NOx: {nox_val:>5} ppb")
            else:
                print(f"[ERROR] Código {respuesta.status_code}: {respuesta.text}")
        except Exception as e:
            print(f"[CRÍTICO] Error de conexión: {e}")

        # Si PM2.5 es crítico, acelera la frecuencia de envío para alertar antes
        if pm25_val > 35.0:
            print("🚨 [ALERTA] PM2.5 superó los 35 µg/m³. Acelerando ráfaga a 2 segundos.")
            tiempo_espera = 2
        else:
            tiempo_espera = 10

        print(f"⏳ Esperando {tiempo_espera} segundos...\n")
        time.sleep(tiempo_espera)


if __name__ == "__main__":
    enviar_telemetria()