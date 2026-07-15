# Módulo de autenticación y seguridad — maneja JWT y hashing de contraseñas
from passlib.context import CryptContext
from datetime import datetime, timedelta, timezone
from jose import JWTError, jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer

# Clave secreta para firmar los tokens JWT (cambiar en producción)
SECRET_KEY = "SUPER_SECRETA_CLAVE_GEMELO_DIGITAL_123"
# Algoritmo de firma del token
ALGORITHM = "HS256"
# Tiempo de vida del token en minutos antes de expirar
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# Contexto de encriptación: usa bcrypt para hashear contraseñas de forma segura
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
# Esquema OAuth2: extrae el token Bearer del header Authorization
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/usuarios/login")


# Compara la contraseña en texto plano con el hash almacenado en la BD
def verificar_password(password_normal: str, password_encriptada: str):
    return pwd_context.verify(password_normal, password_encriptada)


# Genera el hash seguro de una contraseña antes de guardarla en la BD
def obtener_password_hash(password_normal: str):
    return pwd_context.hash(password_normal)


# Crea y firma un nuevo JWT con los datos del usuario y su fecha de expiración
def crear_token_acceso(datos: dict):
    datos_a_codificar = datos.copy()
    # Calcula cuándo expira el token sumando los minutos configurados
    fecha_expiracion = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    datos_a_codificar.update({"exp": fecha_expiracion})
    return jwt.encode(datos_a_codificar, SECRET_KEY, algorithm=ALGORITHM)


# Dependencia de FastAPI: valida el token Bearer en cada ruta protegida.
# Si el token es inválido o expiró, lanza un error 401 Unauthorized.
def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token inválido o expirado. Por favor inicie sesión nuevamente.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        # Decodifica el token y extrae el nombre de usuario del campo 'sub'
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    return username
