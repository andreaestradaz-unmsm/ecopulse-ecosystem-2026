class Station {
  final int id;
  final String name;
  final String zone;

  Station({required this.id, required this.name, required this.zone});

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['id'],
      name: json['name'],
      zone: json['zone'],
    );
  }
}

class Emission {
  final int id;
  final int stationId;
  final double pm25;
  final double co2;
  final double nox;
  final String timestamp;

  Emission({
    required this.id,
    required this.stationId,
    required this.pm25,
    required this.co2,
    required this.nox,
    required this.timestamp,
  });

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
