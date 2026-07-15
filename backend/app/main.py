# Punto de entrada principal de la API REST — registra todos los endpoints de EcoPulse
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from . import database
from app import models, schemas, auth
from app.database import engine, get_db

from fastapi.middleware.cors import CORSMiddleware

# Instancia de la aplicación FastAPI con metadatos para la documentación automática
app = FastAPI(
    title="API de Monitoreo Ambiental - Zona Industrial",
    description="Sistema para capturar y auditar emisiones (PM2.5, CO2, NOx) en tiempo real.",
    version="1.0.0"
)

# Middleware CORS: permite peticiones desde cualquier origen (Flutter, Godot, navegadores)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Crea las tablas en la BD automáticamente si no existen al iniciar el servidor
models.Base.metadata.create_all(bind=engine)


# Health-check: confirma que el servidor está activo
@app.get("/")
def leer_raiz():
    return {"mensaje": "¡Bienvenido al Backend del Gemelo Digital Ambiental! Todo funcionando al 100%."}


# --- Endpoints de Usuarios ---

# Registra un nuevo usuario verificando que el username no esté en uso
@app.post("/api/usuarios/registro", response_model=schemas.UserResponse)
def registrar_usuario(usuario: schemas.UserCreate, db: Session = Depends(get_db)):
    usuario_existente = db.query(models.User).filter(models.User.username == usuario.username).first()
    if usuario_existente:
        raise HTTPException(status_code=400, detail="El nombre de usuario ya está registrado")
    password_encriptada = auth.obtener_password_hash(usuario.password)
    nuevo_usuario = models.User(username=usuario.username, hashed_password=password_encriptada)
    db.add(nuevo_usuario)
    db.commit()
    db.refresh(nuevo_usuario)
    return nuevo_usuario


# Valida las credenciales y devuelve un token JWT Bearer para autenticar futuras peticiones
@app.post("/api/usuarios/login")
def iniciar_sesion(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    usuario = db.query(models.User).filter(models.User.username == form_data.username).first()
    if not usuario or not auth.verificar_password(form_data.password, usuario.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario o contraseña incorrectos",
            headers={"WWW-Authenticate": "Bearer"},
        )
    token_acceso = auth.crear_token_acceso(datos={"sub": usuario.username})
    return {"access_token": token_acceso, "token_type": "bearer"}


# --- Endpoints de Estaciones ---

# Crea una nueva estación de monitoreo (requiere estar autenticado)
@app.post("/api/estaciones", response_model=schemas.StationResponse)
def crear_estacion(estacion: schemas.StationCreate, db: Session = Depends(get_db), current_user: str = Depends(auth.get_current_user)):
    nueva_estacion = models.Station(**estacion.model_dump())
    db.add(nueva_estacion)
    db.commit()
    db.refresh(nueva_estacion)
    return nueva_estacion


# Devuelve la lista completa de estaciones registradas en el sistema
@app.get("/api/estaciones", response_model=list[schemas.StationResponse])
def obtener_estaciones(db: Session = Depends(get_db), current_user: str = Depends(auth.get_current_user)):
    return db.query(models.Station).all()


# Actualiza el nombre y la zona de una estación existente por su ID
@app.put("/api/estaciones/{station_id}", response_model=schemas.StationResponse)
def actualizar_estacion(station_id: int, estacion: schemas.StationCreate, db: Session = Depends(get_db), current_user: str = Depends(auth.get_current_user)):
    estacion_db = db.query(models.Station).filter(models.Station.id == station_id).first()
    if not estacion_db:
        raise HTTPException(status_code=404, detail="Estación no encontrada")
    estacion_db.name = estacion.name
    estacion_db.zone = estacion.zone
    db.commit()
    db.refresh(estacion_db)
    return estacion_db


# Elimina una estación y en cascada todas sus emisiones asociadas
@app.delete("/api/estaciones/{station_id}")
def eliminar_estacion(station_id: int, db: Session = Depends(get_db), current_user: str = Depends(auth.get_current_user)):
    estacion_db = db.query(models.Station).filter(models.Station.id == station_id).first()
    if not estacion_db:
        raise HTTPException(status_code=404, detail="Estación no encontrada")

    # Borra primero las emisiones vinculadas para respetar la integridad referencial
    db.query(models.Emission).filter(models.Emission.station_id == station_id).delete()
    db.delete(estacion_db)
    db.commit()
    return {"mensaje": "Estación eliminada correctamente"}


# --- Endpoints de Emisiones ---

# Registra una nueva lectura de sensor (PM2.5, CO2, NOx) para una estación
@app.post("/api/emisiones", response_model=schemas.EmissionResponse)
def crear_emision(emision: schemas.EmissionCreate, db: Session = Depends(get_db), current_user: str = Depends(auth.get_current_user)):
    # Verifica que la estación destino exista antes de insertar la lectura
    estacion_db = db.query(models.Station).filter(models.Station.id == emision.station_id).first()
    if not estacion_db:
         raise HTTPException(status_code=404, detail="La estación indicada no existe.")
    nueva_emision_db = models.Emission(**emision.model_dump())
    db.add(nueva_emision_db)
    db.commit()
    db.refresh(nueva_emision_db)
    return nueva_emision_db


# Devuelve las últimas N emisiones ordenadas por ID descendente (más reciente primero)
@app.get("/api/emisiones", response_model=list[schemas.EmissionResponse])
def obtener_emisiones(limite: int = 100, db: Session = Depends(get_db), current_user: str = Depends(auth.get_current_user)):
    return db.query(models.Emission).order_by(models.Emission.id.desc()).limit(limite).all()


# Endpoint especial consumido por Flutter y Godot: devuelve el último dato de cada estación
# en un único JSON plano para renderizar el dashboard y la simulación 2D en tiempo real
@app.get("/app/datos_ambientales")
def obtener_datos_ambientales(db: Session = Depends(get_db), current_user: str = Depends(auth.get_current_user)):
    from app import models

    estaciones = db.query(models.Station).all()

    resultado = {
        "status": "success",
        "estaciones": {}
    }

    ultima_emision_general = None
    ultima_station_name = "Sin datos"

    if estaciones:
        for estacion in estaciones:
            # Obtiene sólo la emisión más reciente de esta estación
            ultima_emision = db.query(models.Emission).filter(
                models.Emission.station_id == estacion.id
            ).order_by(models.Emission.id.desc()).first()

            if ultima_emision:
                # Agrega los datos de la estación al diccionario de respuesta
                resultado["estaciones"][str(estacion.id)] = {
                    "id": estacion.id,
                    "nombre": estacion.name,
                    "zona": estacion.zone,
                    "pm25": ultima_emision.pm25,
                    "co2": ultima_emision.co2,
                    "nox": ultima_emision.nox,
                    "timestamp": ultima_emision.timestamp.isoformat()
                }
                resultado[f"pm25_{estacion.id}"] = ultima_emision.pm25
                resultado[f"co2_{estacion.id}"] = ultima_emision.co2
                resultado[f"nox_{estacion.id}"] = ultima_emision.nox

                # Rastrea la emisión más reciente de todo el sistema para los campos globales
                if ultima_emision_general is None or ultima_emision.id > ultima_emision_general.id:
                    ultima_emision_general = ultima_emision
                    ultima_station_name = estacion.name

        # Expone los valores globales (de la estación con dato más reciente)
        if ultima_emision_general:
            resultado["pm25"] = ultima_emision_general.pm25
            resultado["co2"] = ultima_emision_general.co2
            resultado["nox"] = ultima_emision_general.nox
            resultado["station_name"] = ultima_station_name
        else:
            resultado["pm25"] = 0.0
            resultado["co2"] = 0.0
            resultado["nox"] = 0.0
            resultado["station_name"] = "Sin datos"

        return resultado

    # Si no hay estaciones creadas aún, devuelve respuesta vacía con ceros
    return {
        "status": "no_data",
        "estaciones": {},
        "pm25": 0.0,
        "co2": 0.0,
        "nox": 0.0,
        "station_name": "Sin datos",
        "message": "No hay estaciones registradas"
    }
