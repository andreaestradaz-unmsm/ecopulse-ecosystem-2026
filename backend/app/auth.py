
from passlib.context import CryptContext

from datetime import datetime, timedelta, timezone

from jose import JWTError, jwt

SECRET_KEY = "SUPER_SECRETA_CLAVE_GEMELO_DIGITAL_123"

ALGORITHM = "HS256"

ACCESS_TOKEN_EXPIRE_MINUTES = 30


pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def verificar_password(password_normal: str, password_encriptada: str):
    return pwd_context.verify(password_normal, password_encriptada)

def obtener_password_hash(password_normal: str):
    return pwd_context.hash(password_normal)

def crear_token_acceso(datos: dict):
    datos_a_codificar = datos.copy()
    
    fecha_expiracion = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    
    datos_a_codificar.update({"exp": fecha_expiracion})
    
    token_jwt = jwt.encode(datos_a_codificar, SECRET_KEY, algorithm=ALGORITHM)

    return token_jwt
