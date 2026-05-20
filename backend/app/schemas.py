from pydantic import BaseModel
from datetime import datetime

class StationBase(BaseModel):
    name: str
    zone: str

class StationCreate(StationBase):
    pass

class StationResponse(StationBase):
    id: int

    class Config:
        from_attributes = True

class EmissionBase(BaseModel):
    station_id: int
    pm25: float
    co2: float
    nox: float

class EmissionCreate(EmissionBase):
    pass

class EmissionResponse(EmissionBase):
    id: int
    timestamp: datetime

    class Config:
        from_attributes = True

class UserBase(BaseModel):
    username: str

class UserCreate(UserBase):
    password: str

class UserResponse(UserBase):
    id: int

    class Config:
        from_attributes = True
