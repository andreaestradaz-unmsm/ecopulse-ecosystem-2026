# Configuración central de la conexión a la base de datos SQLite con SQLAlchemy
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

# Ruta al archivo local de la base de datos SQLite
SQLALCHEMY_DATABASE_URL = "sqlite:///./emisiones.db"

# Motor de SQLAlchemy — check_same_thread=False permite uso con múltiples hilos (necesario en FastAPI)
engine = create_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)

# Fábrica de sesiones: cada request de la API abrirá una sesión independiente
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Clase base de la que heredan todos los modelos ORM del proyecto
Base = declarative_base()


# Generador de sesión de BD para usar como dependencia en los endpoints de FastAPI.
# Garantiza que la sesión se cierre correctamente al finalizar cada request.
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
