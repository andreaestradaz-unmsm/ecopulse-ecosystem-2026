# Esquemas Pydantic — definen la forma de los datos que entran y salen de la API
from pydantic import BaseModel
from datetime import datetime


# --- Esquemas de Estación ---

# Campos base compartidos por los esquemas de creación y respuesta
class StationBase(BaseModel):
    name: str   # Nombre de la estación
    zone: str   # Zona o ubicación

# Esquema de entrada: datos necesarios para crear una nueva estación
class StationCreate(StationBase):
    pass

# Esquema de respuesta: lo que devuelve la API al consultar una estación (incluye id)
class StationResponse(StationBase):
    id: int

    class Config:
        from_attributes = True  # Permite construir desde objetos ORM de SQLAlchemy


# --- Esquemas de Emisión ---

# Campos base de una lectura de sensor
class EmissionBase(BaseModel):
    station_id: int   # ID de la estación que generó la lectura
    pm25: float       # Material particulado en µg/m³
    co2: float        # Dióxido de carbono en ppm
    nox: float        # Óxidos de nitrógeno en ppb

# Esquema de entrada: datos para registrar una nueva emisión
class EmissionCreate(EmissionBase):
    pass

# Esquema de respuesta: incluye id y timestamp asignados por la BD
class EmissionResponse(EmissionBase):
    id: int
    timestamp: datetime

    class Config:
        from_attributes = True


# --- Esquemas de Usuario ---

# Campo base compartido
class UserBase(BaseModel):
    username: str

# Esquema de entrada para registro: incluye la contraseña en texto plano
class UserCreate(UserBase):
    password: str

# Esquema de respuesta: se devuelve sin contraseña por seguridad
class UserResponse(UserBase):
    id: int

    class Config:
        from_attributes = True
