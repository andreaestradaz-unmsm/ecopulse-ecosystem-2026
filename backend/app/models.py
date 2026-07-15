# Modelos ORM que mapean las tablas de la base de datos SQLite con SQLAlchemy
from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.database import Base
import datetime


# Tabla 'users' — almacena las credenciales de los usuarios que acceden al sistema
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)   # Nombre de usuario único
    hashed_password = Column(String)                     # Contraseña hasheada con bcrypt


# Tabla 'stations' — representa cada estación física de monitoreo ambiental
class Station(Base):
    __tablename__ = "stations"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True)   # Nombre descriptivo de la estación
    zone = Column(String)                             # Zona o ubicación geográfica

    # Relación 1-a-muchos: una estación puede tener muchas lecturas de emisión
    emissions = relationship("Emission", back_populates="station")


# Tabla 'emissions' — registra cada lectura de sensor (PM2.5, CO2, NOx) con marca de tiempo
class Emission(Base):
    __tablename__ = "emissions"
    id = Column(Integer, primary_key=True, index=True)

    # Clave foránea que vincula la lectura a su estación de origen
    station_id = Column(Integer, ForeignKey("stations.id"))

    pm25 = Column(Float)       # Material particulado fino en µg/m³
    co2 = Column(Float)        # Dióxido de carbono en ppm
    nox = Column(Float)        # Óxidos de nitrógeno en ppb
    # Se registra automáticamente la fecha y hora UTC de cada lectura
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)

    # Relación inversa: permite acceder a la estación desde una emisión
    station = relationship("Station", back_populates="emissions")
