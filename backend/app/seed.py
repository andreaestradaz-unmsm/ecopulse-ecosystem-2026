# Script de inicialización de la base de datos — se ejecuta una sola vez para preparar el entorno
import datetime
from sqlalchemy.orm import Session
from app.database import SessionLocal, engine, Base
from app import models, auth


# Función principal de seed: crea tablas y datos mínimos para que el sistema funcione
def seed_database():
    print("[MOCK-SEED] Creando tablas de prueba en la base de datos...")
    # Genera todas las tablas definidas en los modelos ORM si todavía no existen
    Base.metadata.create_all(bind=engine)

    db: Session = SessionLocal()
    try:
        # Verifica si el usuario 'admin' ya existe para no duplicarlo
        admin_user = db.query(models.User).filter(models.User.username == "admin").first()
        if not admin_user:
            print("[MOCK-SEED] Creando usuario admin...")
            # Hashea la contraseña antes de guardarla en la BD
            hashed_pw = auth.obtener_password_hash("admin")
            nuevo_admin = models.User(username="admin", hashed_password=hashed_pw)
            db.add(nuevo_admin)
            db.commit()
            print("[MOCK-SEED] Usuario admin creado exitosamente!")
        else:
            print("[MOCK-SEED] Usuario admin ya existe.")

        # Las estaciones NO se crean aquí: deben registrarse desde la app Flutter
        # para que los sensores IoT las detecten y comiencen a enviar datos automáticamente
        print("[MOCK-SEED] Las estaciones se crearán dinámicamente desde Flutter.")
        print("[MOCK-SEED] Solo crea estaciones en la app móvil y los sensores se sincronizarán automáticamente.")

    except Exception as e:
        print(f"[MOCK-SEED] [ERROR] Error al inicializar la BD: {e}")
        db.rollback()
    finally:
        # Siempre cierra la sesión al terminar, con o sin error
        db.close()


# Permite ejecutar el seed directamente: python -m app.seed
if __name__ == "__main__":
    seed_database()
