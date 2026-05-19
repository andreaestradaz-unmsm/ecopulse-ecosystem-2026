from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.database import Base
import datetime

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    hashed_password = Column(String)

class Station(Base):
    __tablename__ = "stations"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True)
    zone = Column(String)
    
    # Relación: Una estación tiene muchas emisiones
    emissions = relationship("Emission", back_populates="station")

class Emission(Base):
    __tablename__ = "emissions"
    id = Column(Integer, primary_key=True, index=True)
    
    # Llave foránea vinculada a la estación
    station_id = Column(Integer, ForeignKey("stations.id"))
    
    pm25 = Column(Float)
    co2 = Column(Float)
    nox = Column(Float)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
    
    station = relationship("Station", back_populates="emissions")