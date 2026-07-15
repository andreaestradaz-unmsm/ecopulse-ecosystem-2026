// Capa de servicios HTTP — centraliza toda la comunicación con la API REST del backend
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

// Configuración global de conexión al servidor backend.
// La IP y el puerto son ajustables desde la pantalla de configuración (SettingsScreen).
class ApiConfig {
  static String serverIp = "127.0.0.1";  // IP del servidor donde corre FastAPI
  static String port = "8000";
  static String? token;       // Token JWT activo; null si el usuario no ha iniciado sesión
  static String? userLogged;  // Nombre del usuario autenticado actualmente

  // Construye la URL base dinámicamente según los valores configurados
  static String get baseUrl => "http://$serverIp:$port";
}

// Servicio de API: métodos estáticos para cada operación CRUD disponible.
// Todos los métodos inyectan automáticamente el header de autorización si hay sesión activa.
class ApiService {
  // Construye los headers comunes para cada petición (Content-Type + Authorization)
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (ApiConfig.token != null) 'Authorization': 'Bearer ${ApiConfig.token}',
      };

  // Obtiene la lista completa de estaciones registradas en el sistema
  static Future<List<Station>> getStations() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/estaciones'), headers: _headers);
    if (response.statusCode == 200) {
      Iterable l = json.decode(response.body);
      return List<Station>.from(l.map((model) => Station.fromJson(model)));
    } else {
      throw Exception('Failed to load stations');
    }
  }

  // Crea una nueva estación con el nombre y zona proporcionados
  static Future<Station> createStation(String name, String zone) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/estaciones'),
      headers: _headers,
      body: json.encode({'name': name, 'zone': zone}),
    );
    if (response.statusCode == 200) {
      return Station.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create station');
    }
  }

  // Elimina una estación por su ID (el backend también elimina sus emisiones)
  static Future<void> deleteStation(int id) async {
    final response = await http.delete(Uri.parse('${ApiConfig.baseUrl}/api/estaciones/$id'), headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete station');
    }
  }

  // Obtiene el historial de emisiones (últimas 100 lecturas por defecto)
  static Future<List<Emission>> getEmissions() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/emisiones'), headers: _headers);
    if (response.statusCode == 200) {
      Iterable l = json.decode(response.body);
      return List<Emission>.from(l.map((model) => Emission.fromJson(model)));
    } else {
      throw Exception('Failed to load emissions');
    }
  }

  // Registra manualmente una nueva lectura de emisión para una estación específica
  static Future<Emission> createEmission(int stationId, double pm25, double co2, double nox) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/emisiones'),
      headers: _headers,
      body: json.encode({
        'station_id': stationId,
        'pm25': pm25,
        'co2': co2,
        'nox': nox,
      }),
    );
    if (response.statusCode == 200) {
      return Emission.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create emission');
    }
  }
}