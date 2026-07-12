# Documentación Detallada del Backend

A continuación se detalla línea por línea el funcionamiento, propósito y sintaxis de los principales archivos del backend. Esta guía explica cómo cada línea encaja en el ecosistema, qué hace y a dónde lleva.

## 1. `auth.py`
Este archivo maneja todo lo relacionado con la seguridad: encriptación de contraseñas y generación/verificación de tokens JWT para proteger las rutas.

```python
1: from passlib.context import CryptContext
```
**Función:** Importa `CryptContext` de la librería `passlib`. Se utiliza para definir la configuración y el algoritmo con el cual se van a encriptar (hashear) las contraseñas.

```python
2: from datetime import datetime, timedelta, timezone
```
**Función:** Importa módulos para manejar fechas y tiempos. Se usa principalmente para calcular el tiempo exacto en que un token JWT va a expirar.

```python
3: from jose import JWTError, jwt
```
**Función:** Importa la librería `jose` para crear (`encode`) y leer (`decode`) JSON Web Tokens (JWT), además del manejo de errores de token (`JWTError`).

```python
4: from fastapi import Depends, HTTPException, status
5: from fastapi.security import OAuth2PasswordBearer
```
**Función:** Importa herramientas clave de FastAPI. `Depends` para inyección de dependencias, `HTTPException` para arrojar errores HTTP, y `OAuth2PasswordBearer` para extraer de manera automática el token `Bearer` de la cabecera de las peticiones.

```python
7: SECRET_KEY = "SUPER_SECRETA_CLAVE_GEMELO_DIGITAL_123"
8: ALGORITHM = "HS256"
9: ACCESS_TOKEN_EXPIRE_MINUTES = 30
```
**Función:** Configuraciones estáticas. `SECRET_KEY` es la llave maestra para firmar los tokens (en producción no debe estar expuesta en el código). `ALGORITHM` es el tipo de encriptación del JWT. `ACCESS_TOKEN_EXPIRE_MINUTES` indica que el usuario será desconectado tras 30 minutos de su login.

```python
11: pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
```
**Función:** Crea el contexto de encriptación indicándole a Passlib que use el robusto algoritmo `bcrypt`.

```python
12: oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/usuarios/login")
```
**Función:** Define el esquema de seguridad. Le dice a FastAPI y a la documentación integrada (Swagger) que la ruta para autenticarse y recibir el token es `/api/usuarios/login`.

```python
14: def verificar_password(password_normal: str, password_encriptada: str):
15:     return pwd_context.verify(password_normal, password_encriptada)
```
**Función:** Toma la contraseña ingresada por el usuario (en texto plano) y la compara contra el hash de la base de datos usando `verify()`. Retorna True o False.

```python
17: def obtener_password_hash(password_normal: str):
18:     return pwd_context.hash(password_normal)
```
**Función:** Cuando se registra un usuario, esta función recibe la contraseña en texto plano y retorna un string irreconocible (hash) usando bcrypt, para ser guardado en la base de datos.

```python
20: def crear_token_acceso(datos: dict):
21:     datos_a_codificar = datos.copy()
22:     fecha_expiracion = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
23:     datos_a_codificar.update({"exp": fecha_expiracion})
24:     return jwt.encode(datos_a_codificar, SECRET_KEY, algorithm=ALGORITHM)
```
**Función:** Crea el token JWT real. Recibe los `datos` (usualmente el username), genera una fecha límite sumando 30 minutos al momento actual, añade esta expiración al diccionario de datos con la clave `"exp"` y luego genera el token firmado (`jwt.encode`).

```python
26: def get_current_user(token: str = Depends(oauth2_scheme)):
```
**Función:** Es la dependencia que se pone en las rutas protegidas. Utiliza `oauth2_scheme` para extraer automáticamente el token enviado por el cliente. 

```python
31:     credentials_exception = HTTPException(
32:         status_code=status.HTTP_401_UNAUTHORIZED,
33:         detail="Token inválido o expirado. Por favor inicie sesión nuevamente.",
34:         headers={"WWW-Authenticate": "Bearer"},
35:     )
```
**Función:** Define una plantilla de error HTTP 401. Si algo falla con el token, se lanzará esta excepción indicando que el acceso no está autorizado.

```python
36:     try:
37:         payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
38:         username: str = payload.get("sub")
39:         if username is None:
40:             raise credentials_exception
41:     except JWTError:
42:         raise credentials_exception
43:     return username
```
**Función:** Intenta decodificar el token para ver qué hay adentro. Si logra desencriptarlo y no ha expirado, extrae el `username` del campo `"sub"` (Subject). Si el token fue manipulado, expiró, o no contiene username, lanza el error `credentials_exception`. Finalmente, si es exitoso, retorna el `username`.

---

## 2. `database.py`
Este archivo configura la conexión central a la base de datos (SQLite en este caso) utilizando SQLAlchemy.

```python
1: from sqlalchemy import create_engine
2: from sqlalchemy.orm import sessionmaker, declarative_base
```
**Función:** Importa las funciones base de SQLAlchemy. `create_engine` inicializa el motor de DB, `sessionmaker` fabrica sesiones para las consultas, y `declarative_base` sirve para crear las clases de nuestros modelos.

```python
4: SQLALCHEMY_DATABASE_URL = "sqlite:///./emisiones.db"
```
**Función:** Define la ruta de la base de datos. `sqlite:///./` indica que será un archivo SQLite local llamado `emisiones.db` en la carpeta raíz.

```python
6: engine = create_engine(
7:     SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
8: )
```
**Función:** Inicia el motor. En SQLite, por defecto las conexiones no pueden compartirse entre "threads" (hilos) del procesador. Como FastAPI es asíncrono y usa varios hilos, se añade `check_same_thread=False` para evitar cuelgues o bloqueos.

```python
10: SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
```
**Función:** Crea una fábrica de sesiones llamada `SessionLocal`. Cada vez que queramos consultar la DB, crearemos una instancia a partir de esto. Se apagan el autocommit y autoflush para manejar las transacciones manualmente y de forma segura.

```python
12: Base = declarative_base()
```
**Función:** `Base` es la clase madre. Todos los modelos de tablas en `models.py` deberán heredar de `Base` para que SQLAlchemy sepa que son tablas.

```python
14: def get_db():
15:     db = SessionLocal() # Abrimos la conexión (inicia el chat)
16:     try:
17:         yield db 
18:     finally:
19:         db.close()
```
**Función:** Generador de dependencias. Se ejecuta por cada petición HTTP que requiera la DB. Abre una conexión `db`, la entrega al endpoint con `yield`, espera a que la petición termine y luego en el bloque `finally` cierra la conexión obligatoriamente. Evita fugas de memoria.

---

## 3. `models.py`
Define las Tablas de la Base de Datos como si fueran clases de Python usando el ORM.

```python
1: from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
2: from sqlalchemy.orm import relationship
3: from app.database import Base
4: import datetime
```
**Función:** Importa los tipos de datos para las columnas, las llaves foráneas (`ForeignKey`), relaciones (`relationship`) y la clase `Base` que creamos en `database.py`.

```python
6: class User(Base):
7:     __tablename__ = "users"
8:     id = Column(Integer, primary_key=True, index=True)
9:     username = Column(String, unique=True, index=True)
10:     hashed_password = Column(String)
```
**Función:** Define la tabla `users`. Su clave primaria es `id`. Tiene una columna `username` que debe ser única e indexada para búsquedas rápidas. Almacena el `hashed_password` que creamos en `auth.py`.

```python
12: class Station(Base):
13:     __tablename__ = "stations"
14:     id = Column(Integer, primary_key=True, index=True)
15:     name = Column(String, unique=True, index=True)
16:     zone = Column(String)
17:     
18:     # Relación: Una estación tiene muchas emisiones
19:     emissions = relationship("Emission", back_populates="station")
```
**Función:** Define la tabla `stations` (estaciones). Tiene `id`, `name`, y `zone`. La línea 19 crea un enlace virtual bidireccional (`relationship`) con el modelo `Emission`, permitiendo acceder a `estacion.emissions` para ver todas las métricas de esa estación.

```python
21: class Emission(Base):
22:     __tablename__ = "emissions"
23:     id = Column(Integer, primary_key=True, index=True)
24:     
25:     # Llave foránea vinculada a la estación
26:     station_id = Column(Integer, ForeignKey("stations.id"))
27:     
28:     pm25 = Column(Float)
29:     co2 = Column(Float)
30:     nox = Column(Float)
31:     timestamp = Column(DateTime, default=datetime.datetime.utcnow)
32:     
33:     station = relationship("Station", back_populates="emissions")
```
**Función:** Define la tabla `emissions`. La línea 26 vincula esta tabla con `stations` a través del `station_id` (Foregin Key). Tiene columnas flotantes para los gases y un `timestamp` que por defecto guarda la hora UTC en la que se registra el dato. La línea 33 cierra la relación bidireccional hacia la tabla `Station`.

---

## 4. `schemas.py`
Aquí usamos Pydantic para definir cómo deben verse los datos JSON cuando entran (Peticiones/Requests) y cuando salen (Respuestas/Responses) del API.

```python
1: from pydantic import BaseModel
2: from datetime import datetime
```
**Función:** Importa `BaseModel`, la clase maestra de Pydantic de la cual heredan todos los esquemas, asegurando la validación automática de datos.

```python
4: class StationBase(BaseModel):
5:     name: str 
6:     zone: str
```
**Función:** Es un esquema base con los datos comunes de una estación.

```python
8: class StationCreate(StationBase):
9:     pass
```
**Función:** Hereda de `StationBase`. Sirve para validar los datos cuando un usuario envía un POST para crear una estación. Como hereda, espera un `name` y una `zone`.

```python
11: class StationResponse(StationBase):
12:     id: int
13: 
14:     class Config:
15:         from_attributes = True
```
**Función:** Esquema que se usa al DEVOLVER los datos de una estación. A diferencia del de creación, aquí sí adjuntamos el `id` asignado por la base de datos. La subclase `Config` con `from_attributes = True` le indica a Pydantic que pueda leer objetos mágicos del ORM de SQLAlchemy directamente sin requerir que sean diccionarios.

*(El mismo patrón Base/Create/Response se repite para `Emission` y `User` entre las líneas 17 a 43, dictando los formatos de entrada y salida exactos con tipos como float o str. Cabe destacar `UserCreate` que espera la contraseña plana como input, mientras que `UserResponse` jamás devuelve la contraseña, retornando sólo username e id).*

---

## 5. `main.py`
Es el archivo principal, el cerebro del backend que agrupa las rutas, los modelos, las validaciones y corre el servidor.

```python
1: from fastapi import FastAPI, Depends, HTTPException, status
2: from fastapi.security import OAuth2PasswordRequestForm
3: from sqlalchemy.orm import Session
4: from . import database
5: from app import models, schemas, auth
6: from app.database import engine, get_db
8: from fastapi.middleware.cors import CORSMiddleware
```
**Función:** Importaciones masivas. Todo lo que hemos creado (`models`, `schemas`, `auth`, `database`) converge aquí. Se trae soporte para inyecciones, errores, formularios de login, sesiones de base de datos y middlewares de seguridad (CORS).

```python
10: app = FastAPI(
11:     title="API de Monitoreo Ambiental - Zona Industrial",
...
14: )
```
**Función:** Inicializa la aplicación principal de FastAPI con metadatos que servirán para autogenerar la documentación de Swagger (`/docs`).

```python
16: app.add_middleware(
17:     CORSMiddleware,
18:     allow_origins=["*"], 
...
22: )
```
**Función:** Agrega un middleware para CORS. Permitir orígenes `["*"]` significa que cualquier cliente web o móvil de diferentes puertos/dominios puede conectarse sin ser bloqueado por políticas de navegador.

```python
24: models.Base.metadata.create_all(bind=engine)
```
**Función:** Instrucción que le dice a SQLAlchemy que inspeccione `models.py` y cree el archivo `emisiones.db` y las tablas si no existen aún en el disco duro.

```python
26: @app.get("/")
27: def leer_raiz():
28:     return {"mensaje": "¡Bienvenido al Backend del Gemelo Digital Ambiental! Todo funcionando al 100%."}
```
**Función:** Crea una ruta (endpoint) en la raíz (`/`). Sirve como comprobación de que el servidor está en línea.

```python
31: @app.post("/api/usuarios/registro", response_model=schemas.UserResponse)
32: def registrar_usuario(usuario: schemas.UserCreate, db: Session = Depends(get_db)):
...
41:     return nuevo_usuario
```
**Función:** Endpoint POST para crear cuentas. Utiliza `UserCreate` como input. Valida que el nombre de usuario no exista en la DB. Si existe, tira error 400. Si no, encripta el password importando `auth`, guarda el modelo en la DB (`db.add`, `db.commit`), y retorna los datos limitados por `schemas.UserResponse`.

```python
43: @app.post("/api/usuarios/login")
44: def iniciar_sesion(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
...
53:     return {"access_token": token_acceso, "token_type": "bearer"}
```
**Función:** Endpoint POST para loguearse. Usa `OAuth2PasswordRequestForm` el cual requiere que los datos vengan como formulario (`application/x-www-form-urlencoded`). Verifica en la base de datos si existe el usuario. Si la clave no hace match, lanza 401. Si pasa, crea el JWT llamando a `auth.crear_token_acceso` y lo devuelve.

```python
56: @app.post("/api/estaciones", response_model=schemas.StationResponse)
57: def crear_estacion(estacion: schemas.StationCreate, db: Session = Depends(get_db), current_user: str = Depends(auth.get_current_user)):
...
62:     return nueva_estacion
```
**Función:** Crear Estaciones. Note el `Depends(auth.get_current_user)`. Esto bloquea la ruta. Solo se ejecuta si la petición manda un token JWT válido. Transforma los datos validados del schema a modelo y guarda en la base de datos.

*(Las líneas 64 a 86 tienen las funciones GET, PUT y DELETE para estaciones. Todas repiten el mismo patrón: protegen la ruta con `auth.get_current_user`, luego hacen su respectiva operación de base de datos usando SQLAlchemy y retornan).*

```python
89: @app.post("/api/emisiones", response_model=schemas.EmissionResponse)
90: def crear_emision(emision: schemas.EmissionCreate, db: Session = Depends(get_db), current_user: str = Depends(auth.get_current_user)):
...
```
**Función:** Registra una lectura de contaminación. Protegida. Primero comprueba si la estación a la cual se le quiere asignar (vía el `station_id` en el json) realmente existe (`db.query...`). Si no existe lanza error 404. Si existe, la inserta.

```python
105: @app.get("/app/datos_ambientales")
106: def obtener_datos_ambientales(db: Session = Depends(get_db)):
107:     from app import models 
108:     ultima_emision = db.query(models.Emission).order_by(models.Emission.id.desc()).first()
109:     if ultima_emision:
110:         nivel_fog = min(float(ultima_emision.pm25) / 100.0, 0.5) 
111:         return {"status": "success", "pm25": nivel_fog, "valor_real": ultima_emision.pm25}
112:     return {"status": "no_data", "pm25": 0.01}
```
**Función:** Ruta pública orientada a que un agente externo (como Godot o Flutter) lea la data rápidamente. Hace un query ordenando por id descendente (`desc()`) y extrae solo el primero (`first()`), siendo esta la medición más reciente. Calcula matemáticamente el espesor de la "niebla" (fog) para la simulación visual, y retorna el objeto JSON.

---

## 6. `seed.py`
Un script auxiliar y ejecutable. Se usa desde la terminal y no pertenece a las rutas del API web. Su propósito es poblar ("sembrar") la base de datos con datos base (Mocks) para pruebas rápidas.

```python
16: import datetime
17: from sqlalchemy.orm import Session
18: from app.database import SessionLocal, engine, Base
19: from app import models
```
**Función:** Importa las herramientas de base de datos directamente para actuar sin necesidad de levantar FastAPI.

```python
21: def seed_database():
22:     # 1. Crear las tablas si no existen en SQLite
23:     print("[MOCK-SEED] Creando tablas de prueba en la base de datos...")
24:     Base.metadata.create_all(bind=engine)
```
**Función:** Fuerza manualmente la creación de las tablas si no existieran usando el motor de Base.

```python
26:     db: Session = SessionLocal()
27:     try:
28:         estacion_existente = db.query(models.Station).filter(models.Station.name == "Estación Central").first()
```
**Función:** Abre una sesión con la BD. Busca si la estación de prueba ("Estación Central") ya fue insertada anteriormente para evitar duplicados indeseados si se ejecuta el script varias veces.

```python
31:         if not estacion_existente:
32:             print("[MOCK-SEED] Insertando estación de monitoreo simulada...")
33:             estacion_central = models.Station(
34:                 name="Estación Central",
35:                 zone="Parque Industrial de Lima"
36:             )
37:             db.add(estacion_central)
38:             db.commit()
39:             db.refresh(estacion_central)
...
```
**Función:** Si la estación no existe, la crea como un nuevo objeto de modelo, la añade (`add`), consolida (`commit`) para persistirla y la actualiza (`refresh`) para obtener el ID recién asignado en disco.

```python
48:         nueva_emision = models.Emission(
49:             station_id=station_id,
50:             pm25=28.4,  # Nivel moderado (se visualizará color naranja en Flutter)
51:             co2=385.2,  # ppm
52:             nox=42.1,   # ppb
53:             timestamp=datetime.datetime.utcnow()
54:         )
55:         db.add(nueva_emision)
56:         db.commit()
```
**Función:** Crea automáticamente una "lectura inicial" de gases atada a la estación de prueba con valores arbitrarios fijos. Hace commit para inyectarlos.

```python
59:     except Exception as e:
60:         print(f"[MOCK-SEED] [ERROR] No se pudieron cargar los datos de prueba: {e}")
61:         db.rollback()
62:     finally:
63:         db.close()
```
**Función:** Captura errores. Si algo falla durante el proceso, hace un `rollback()` revirtiendo cualquier cambio a la mitad para evitar datos corruptos. Siempre cierra la conexión (`finally`) al terminar.

```python
65: if __name__ == "__main__":
66:     seed_database()
```
**Función:** Le indica a Python que si el archivo se está corriendo directamente desde la consola (`python seed.py`) debe disparar automáticamente la función `seed_database()`.
