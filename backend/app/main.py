from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from app import models, schemas, auth
from app.database import engine, get_db

from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

# Configuración de CORS para permitir que tu simulación en Godot consulte la API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Permite conexiones desde cualquier origen local/externo
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

models.Base.metadata.create_all(bind=engine)


app = FastAPI(
    title="API de Monitoreo Ambiental - Zona Industrial",
    description="Sistema para capturar y auditar emisiones (PM2.5, CO2, NOx) en tiempo real.",
    version="1.0.0"
)

@app.get("/")
def leer_raiz():
    return {"mensaje": "¡Bienvenido al Backend del Gemelo Digital Ambiental! Todo funcionando al 100%."}

@app.post("/api/emisiones", response_model=schemas.EmissionResponse)
def crear_emision(emision: schemas.EmissionCreate, db: Session = Depends(get_db)):
    """
    Este endpoint simula que un sensor en la fábrica nos acaba de enviar datos.
    """
    nueva_emision_db = models.Emission(**emision.model_dump())
    
    db.add(nueva_emision_db)
    
    db.commit()

    db.refresh(nueva_emision_db)
    
    return nueva_emision_db

@app.get("/api/emisiones", response_model=list[schemas.EmissionResponse])
def obtener_emisiones(limite: int = 100, db: Session = Depends(get_db)):
    """
    Este endpoint se usará en el Dashboard (Panel de Control) para ver el historial.
    """

    historial = db.query(models.Emission).limit(limite).all()

    return historial

@app.post("/api/usuarios/registro", response_model=schemas.UserResponse)
def registrar_usuario(usuario: schemas.UserCreate, db: Session = Depends(get_db)):
    """
    Este endpoint permite crear un auditor o administrador en el sistema.
    """
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
    """
    Este endpoint verifica que seas quien dices ser. Si es así, te entrega tu "ticket" (Token JWT).
    """
    usuario = db.query(models.User).filter(models.User.username == form_data.username).first()
    
    if not usuario or not auth.verificar_password(form_data.password, usuario.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario o contraseña incorrectos",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    token_acceso = auth.crear_token_acceso(datos={"sub": usuario.username})

    return {"access_token": token_acceso, "token_type": "bearer"}

@app.get("/app/datos_ambientales")
def obtener_datos_ambientales(db: Session = Depends(get_db)):
    """
    Endpoint dedicado para conectar con el Gemelo Digital en Godot.
    Extrae la última emisión registrada en la base de datos para simularla en tiempo real.
    """
    from app import models  # Asegurar la importación del modelo de datos
    
    # Buscamos la última emisión guardada en la base de datos por los sensores
    ultima_emision = db.query(models.Emission).order_spec(models.Emission.id.desc()).first()
    
    if ultima_emision:
        # Mapeamos el valor para que sea un flotante adecuado para la niebla de Godot
        # Por ejemplo, si el PM2.5 es 50, lo escalamos a un rango visible (ej. 0.15)
        # Aquí una regla de tres simple o un mapeo directo según sus datos:
        nivel_fog = min(float(ultima_emision.pm25) / 100.0, 0.5) 
        
        return {
            "status": "success",
            "pm25": nivel_fog,
            "valor_real": ultima_emision.pm25
        }
    
    # Si la base de datos está vacía, enviamos un valor por defecto (día limpio)
    return {
        "status": "no_data",
        "pm25": 0.01
    }
