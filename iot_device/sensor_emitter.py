import requests
import time
import random

API_URL = "http://127.0.0.1:8000/api/emisiones"
TOKEN_URL = "http://127.0.0.1:8000/api/usuarios/login"

STATION_ID = 1

USUARIO = "admin"
PASSWORD = "admin"

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

def enviar_telemetria():
    print("=========================================================")
    print(" 🏭 Iniciando Sensor IoT - EcoPulse (Gemelo Digital) ")
    print("=========================================================")
    
    token = obtener_token()
    if not token:
        print("Deteniendo sensor por falta de credenciales.")
        return

    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}"
    }

    while True:
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

        if pm25_val > 35.0:
            print("🚨 [ALERTA] PM2.5 superó los 35 µg/m³. Acelerando ráfaga a 2 segundos.")
            tiempo_espera = 2  
        else:
            tiempo_espera = 10 
            
        print(f"⏳ Esperando {tiempo_espera} segundos...\n")
        time.sleep(tiempo_espera)

if __name__ == "__main__":
    enviar_telemetria()