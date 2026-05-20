import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _ambientData;
  bool _isLoading = false;
  String _statusMessage = "Cargando datos...";

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() { _isLoading = true; });
    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/app/datos_ambientales");
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        setState(() {
          _ambientData = jsonDecode(response.body);
          _statusMessage = "Conectado al Backend";
          _isLoading = false;
        });
      } else {
        setState(() {
          _statusMessage = "Error del servidor: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Error de conexión. Verifica la IP del servidor.";
        _isLoading = false;
      });
    }
  }

  Color _getSeverityColor(double pm25) {
    if (pm25 <= 12) return Colors.green;
    if (pm25 <= 35) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final double pm25 = _ambientData?['pm25']?.toDouble() ?? 0.0;
    final double co2 = _ambientData?['co2']?.toDouble() ?? 0.0;
    final double nox = _ambientData?['nox']?.toDouble() ?? 0.0;
    final String station = _ambientData?['station_name'] ?? 'Sin datos';

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Text(
              "Estado: $_statusMessage",
              style: TextStyle(color: _statusMessage == "Conectado al Backend" ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              color: _ambientData == null ? Colors.grey[200] : _getSeverityColor(pm25).withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Text("ESTACIÓN: $station", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else ...[
                      Text(
                        "${pm25.toStringAsFixed(1)} µg/m³",
                        style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: _getSeverityColor(pm25)),
                      ),
                      const Text("Material Particulado (PM 2.5)", style: TextStyle(color: Colors.black54)),
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.co2, color: Colors.blue, size: 40),
              title: const Text("Dióxido de Carbono (CO2)"),
              trailing: Text("${co2.toStringAsFixed(1)} ppm", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.science, color: Colors.purple, size: 40),
              title: const Text("Óxidos de Nitrógeno (NOx)"),
              trailing: Text("${nox.toStringAsFixed(1)} ppb", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchData,
        backgroundColor: Colors.green,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ipController = TextEditingController(text: ApiConfig.serverIp);
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  String _authMessage = "";
  bool _isRegister = false;

  Future<void> _submitAuth() async {
    final username = _userController.text.trim();
    final password = _passwordController.text.trim();
    if (username.isEmpty || password.isEmpty) {
      setState(() { _authMessage = "Completa todos los campos"; });
      return;
    }
    try {
      if (_isRegister) {
        final response = await http.post(
          Uri.parse("${ApiConfig.baseUrl}/api/usuarios/registro"),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': username, 'password': password}),
        );
        if (response.statusCode == 200) {
          setState(() { _authMessage = "¡Registro exitoso! Ya puedes iniciar sesión."; _isRegister = false; });
        } else {
          final err = jsonDecode(response.body);
          setState(() { _authMessage = "Error: ${err['detail'] ?? 'No se pudo registrar'}"; });
        }
      } else {
        final response = await http.post(
          Uri.parse("${ApiConfig.baseUrl}/api/usuarios/login"),
          body: {'username': username, 'password': password},
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            ApiConfig.token = data['access_token'];
            ApiConfig.userLogged = username;
            _authMessage = "¡Sesión iniciada como $username!";
          });
        } else {
          setState(() { _authMessage = "Credenciales incorrectas."; });
        }
      }
    } catch (e) {
      setState(() { _authMessage = "Error de conexión con el servidor."; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool logged = ApiConfig.token != null;
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(labelText: "IP de tu PC (Backend)", border: OutlineInputBorder()),
              onChanged: (val) { ApiConfig.serverIp = val.trim(); },
            ),
            const SizedBox(height: 20),
            if (logged) ...[
              const Icon(Icons.check_circle, color: Colors.green, size: 60),
              const SizedBox(height: 10),
              Text("Sesión iniciada como: ${ApiConfig.userLogged}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () { setState(() { ApiConfig.token = null; ApiConfig.userLogged = null; _authMessage = "Sesión cerrada"; }); },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Cerrar Sesión", style: TextStyle(color: Colors.white)),
              )
            ] else ...[
              Text(_isRegister ? "Registrar Usuario" : "Iniciar Sesión", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(controller: _userController, decoration: const InputDecoration(labelText: "Usuario", border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: "Contraseña", border: OutlineInputBorder())),
              const SizedBox(height: 16),
              if (_authMessage.isNotEmpty) Text(_authMessage, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _submitAuth, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: Text(_isRegister ? "Registrarse" : "Entrar", style: const TextStyle(color: Colors.white))),
              TextButton(
                onPressed: () { 
                  setState(() { 
                    _isRegister = !_isRegister; 
                    _authMessage = ""; 
                  }); 
                }, 
                child: Text(_isRegister ? "¿Ya tienes cuenta? Inicia sesión" : "¿No tienes cuenta? Regístrate"),
              )
            ]
          ],
        ),
      ),
    );
  }
}