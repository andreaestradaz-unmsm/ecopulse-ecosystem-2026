# ==============================================================================
# SCRIPT DE PRUEBA / DESECHABLE (MOCK SEEDER) - ECOPULSE PROJECT
# ==============================================================================
# ESTE ARCHIVO ES EXCLUSIVAMENTE PARA FINES DE PRUEBA LOCAL (HITO 1).
# 
# PROPÓSITO:
# Poblar la base de datos local SQLite ('emisiones.db') con datos de simulación
# iniciales para verificar que el Backend y la App de Flutter se comuniquen 
# correctamente.
#
# NOTA DE DESARROLLO:
# Este script es descartable. Será reemplazado en el Hito 2 (Examen Final)
# cuando los sensores IoT reales envíen telemetría auténtica en tiempo real.
# ==============================================================================

import datetime
from sqlalchemy.orm import Session
from app.database import SessionLocal, engine, Base
from app import models

def seed_database():
    # 1. Crear las tablas si no existen en SQLite
    print("[MOCK-SEED] Creando tablas de prueba en la base de datos...")
    Base.metadata.create_all(bind=engine)
    
    db: Session = SessionLocal()
    try:
        # 2. Verificar si ya existe la estación simulada de prueba
        estacion_existente = db.query(models.Station).filter(models.Station.name == "Estación Central").first()
        
        if not estacion_existente:
            print("[MOCK-SEED] Insertando estación de monitoreo simulada...")
            estacion_central = models.Station(
                name="Estación Central",
                zone="Parque Industrial de Lima"
            )
            db.add(estacion_central)
            db.commit()
            db.refresh(estacion_central)
            print(f"[MOCK-SEED] Estación temporal creada con ID: {estacion_central.id}")
            station_id = estacion_central.id
        else:
            print("[MOCK-SEED] La estación de prueba 'Estación Central' ya existe.")
            station_id = estacion_existente.id

        # 3. Insertar una lectura inicial de emisiones para alimentar la App Móvil
        print("[MOCK-SEED] Generando lectura inicial simulada de PM2.5, CO2 y NOx...")
        nueva_emision = models.Emission(
            station_id=station_id,
            pm25=28.4,  # Nivel moderado (se visualizará color naranja en Flutter)
            co2=385.2,  # ppm
            nox=42.1,   # ppb
            timestamp=datetime.datetime.utcnow()
        )
        db.add(nueva_emision)
        db.commit()
        print("[MOCK-SEED] ¡Datos de prueba iniciales cargados exitosamente!")
        
    except Exception as e:
        print(f"[MOCK-SEED] [ERROR] No se pudieron cargar los datos de prueba: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    seed_database()