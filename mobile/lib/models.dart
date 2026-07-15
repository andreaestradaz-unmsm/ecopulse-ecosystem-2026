// Modelos de datos que representan las entidades devueltas por la API REST

// Representa una estación de monitoreo ambiental
class Station {
  final int id;
  final String name;  // Nombre descriptivo de la estación
  final String zone;  // Zona o ubicación geográfica

  Station({required this.id, required this.name, required this.zone});

  // Deserializa un mapa JSON (respuesta de /api/estaciones) a un objeto Station
  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['id'],
      name: json['name'],
      zone: json['zone'],
    );
  }
}

// Representa una lectura de sensor con sus valores de contaminantes y marca de tiempo
class Emission {
  final int id;
  final int stationId;   // ID de la estación que generó esta lectura
  final double pm25;     // Material particulado fino en µg/m³
  final double co2;      // Dióxido de carbono en ppm
  final double nox;      // Óxidos de nitrógeno en ppb
  final String timestamp;

  Emission({
    required this.id,
    required this.stationId,
    required this.pm25,
    required this.co2,
    required this.nox,
    required this.timestamp,
  });

  // Deserializa un mapa JSON (respuesta de /api/emisiones) a un objeto Emission.
  // Usa ?? 0 para manejar valores nulos que puedan venir del servidor.
  factory Emission.fromJson(Map<String, dynamic> json) {
    return Emission(
      id: json['id'],
      stationId: json['station_id'],
      pm25: (json['pm25'] ?? 0).toDouble(),
      co2: (json['co2'] ?? 0).toDouble(),
      nox: (json['nox'] ?? 0).toDouble(),
      timestamp: json['timestamp'],
    );
  }
}
