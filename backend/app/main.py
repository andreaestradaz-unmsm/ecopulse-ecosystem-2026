from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
<<<<<<< HEAD
from . import database
=======

>>>>>>> 5d2883b9b4dcd1d044cdaefa73b0e3110cafdf8e
from app import models, schemas, auth
from app.database import engine, get_db

from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(
    title="API de Monitoreo Ambiental - Zona Industrial",
    description="Sistema para capturar y auditar emisiones (PM2.5, CO2, NOx) en tiempo real.",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

models.Base.metadata.create_all(bind=engine)

@app.get("/")
def leer_raiz():
    return {"mensaje": "¡Bienvenido al Backend del Gemelo Digital Ambiental! Todo funcionando al 100%."}

# --- USUARIOS ---
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

# --- ESTACIONES (Protegidas) ---
@app.post("/api/estaciones", response_model=schemas.StationResponse)
def crear_estacion(estacion: schemas.StationCreate, db: Session = Depends(get_db), current_user: str = Depends(auth.get_current_user)):
    nueva_estacion = models.Station(**estacion.model_dump())
    db.add(nueva_estacion)
    db.commit()
    db.refresh(nueva_estacion)
    return nueva_estacion

@app.get("/api/estaciones", response_model=list[schemas.StationResponse])
def obtener_estaciones(db: Session = Depends(get_db), current_user: str = Depends(auth.get_current_user)):
    return db.query(models.Station).all()

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

@app.delete("/api/estaciones/{station_id}")
def eliminar_estacion(station_id: int, db: Session = Depends(get_db), current_user: str = Depends(auth.get_current_user)):
    estacion_db = db.query(models.Station).filter(models.Station.id == station_id).first()
    if not estacion_db:
        raise HTTPException(status_code=404, detail="Estación no encontrada")
    db.delete(estacion_db)
    db.commit()
    return {"mensaje": "Estación eliminada correctamente"}

# --- EMISIONES (Protegidas) ---
@app.post("/api/emisiones", response_model=schemas.EmissionResponse)
def crear_emision(emision: schemas.EmissionCreate, db: Session = Depends(get_db), current_user: str = Depends(auth.get_current_user)):
    estacion_db = db.query(models.Station).filter(models.Station.id == emision.station_id).first()
    if not estacion_db:
         raise HTTPException(status_code=404, detail="La estación indicada no existe.")
    nueva_emision_db = models.Emission(**emision.model_dump())
    db.add(nueva_emision_db)
    db.commit()
    db.refresh(nueva_emision_db)
    return nueva_emision_db

@app.get("/api/emisiones", response_model=list[schemas.EmissionResponse])
def obtener_emisiones(limite: int = 100, db: Session = Depends(get_db), current_user: str = Depends(auth.get_current_user)):
    return db.query(models.Emission).limit(limite).all()

# --- GODOT (Pública) ---
@app.get("/app/datos_ambientales")
<<<<<<< HEAD
async def obtener_datos(db: Session = Depends(database.get_db)):
    # 1. Buscamos la última emisión y cargamos la información de la estación vinculada
    # Usamos models.Emission porque así está en tu captura
    lectura = db.query(models.Emission).order_by(models.Emission.id.desc()).first()
    
    if lectura:
        # Si la lectura tiene una estación vinculada, sacamos el nombre de ahí
        nombre_estacion = lectura.station.name if lectura.station else "Estación Central"
        
        return {
            "status": "success",
            "estacion": nombre_estacion,
            "pm25": lectura.pm25,
            "co2": lectura.co2,
            "nox": lectura.nox
        }
    
    return {"status": "error", "message": "No hay datos en la BD"}

    #Arreglar error con @app.get("/app/datos_ambientales"),no devuelve absolutamente nada, ni siquiera un error, solo una respuesta vacía. Esto se debe a que la función no está retornando ningún valor. Para solucionarlo, debes asegurarte de que la función retorne un diccionario con los datos que deseas enviar al cliente. Por ejemplo:
    #lo he intentado cambiar pero nada alv sigue devolviendo solo el dato principal no el co2 ni el nox  
=======
def obtener_datos_ambientales(db: Session = Depends(get_db)):
    from app import models 
    ultima_emision = db.query(models.Emission).order_by(models.Emission.id.desc()).first()
    if ultima_emision:
        nivel_fog = min(float(ultima_emision.pm25) / 100.0, 0.5) 
        return {"status": "success", "pm25": nivel_fog, "valor_real": ultima_emision.pm25}
    return {"status": "no_data", "pm25": 0.01}
>>>>>>> 5d2883b9b4dcd1d044cdaefa73b0e3110cafdf8e
