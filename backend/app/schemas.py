
from pydantic import BaseModel
from datetime import datetime

class EmissionBase(BaseModel):
    factory_name: str 
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
