
from sqlalchemy import Column, Integer, String, Float, DateTime
from app.database import Base
import datetime

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    hashed_password = Column(String)


class Emission(Base):
    __tablename__ = "emissions"

    id = Column(Integer, primary_key=True, index=True)
    
    factory_name = Column(String, index=True)
    
    pm25 = Column(Float)
    
    co2 = Column(Float)
    
    nox = Column(Float)

    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
