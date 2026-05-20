import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiConfig {
  static String serverIp = "127.0.0.1"; 
  static String port = "8000";
  static String? token; 
  static String? userLogged;

  static String get baseUrl => "http://$serverIp:$port";
}

class ApiService {
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (ApiConfig.token != null) 'Authorization': 'Bearer ${ApiConfig.token}',
      };

  static Future<List<Station>> getStations() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/estaciones'), headers: _headers);
    if (response.statusCode == 200) {
      Iterable l = json.decode(response.body);
      return List<Station>.from(l.map((model) => Station.fromJson(model)));
    } else {
      throw Exception('Failed to load stations');
    }
  }

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

  static Future<void> deleteStation(int id) async {
    final response = await http.delete(Uri.parse('${ApiConfig.baseUrl}/api/estaciones/$id'), headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete station');
    }
  }

  static Future<List<Emission>> getEmissions() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/emisiones'), headers: _headers);
    if (response.statusCode == 200) {
      Iterable l = json.decode(response.body);
      return List<Emission>.from(l.map((model) => Emission.fromJson(model)));
    } else {
      throw Exception('Failed to load emissions');
    }
  }

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