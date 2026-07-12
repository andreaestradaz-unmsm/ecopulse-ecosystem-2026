import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'services.dart';
import 'models.dart';

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
      if (ApiConfig.token == null) {
        setState(() {
          _statusMessage = "Debes iniciar sesión primero";
          _ambientData = null;
          _isLoading = false;
        });
        return;
      }
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer ${ApiConfig.token}'},
      ).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        setState(() {
          _ambientData = jsonDecode(response.body);
          _statusMessage = "Conectado al Backend";
          _isLoading = false;
        });
      } else {
        setState(() {
          if (response.statusCode == 401) {
            _statusMessage = "Sesión expirada. Inicia sesión.";
            _ambientData = null;
          } else {
            _statusMessage = "Error del servidor: ${response.statusCode}";
          }
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

class ManagementScreen extends StatefulWidget {
  const ManagementScreen({super.key});
  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen> {
  List<Station> _stations = [];
  Map<int, double> _latestPm25 = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    if (ApiConfig.token == null) return;
    setState(() { _isLoading = true; });
    try {
      final stations = await ApiService.getStations();
      final emissions = await ApiService.getEmissions();
      
      Map<int, Emission> latestEms = {};
      for (var e in emissions) {
        if (!latestEms.containsKey(e.stationId) || e.id > latestEms[e.stationId]!.id) {
          latestEms[e.stationId] = e;
        }
      }
      
      Map<int, double> latestPm25 = {};
      latestEms.forEach((k, v) => latestPm25[k] = v.pm25);

      setState(() { 
        _stations = stations; 
        _latestPm25 = latestPm25;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al cargar estaciones: $e")));
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _addStation() async {
    final nameCtrl = TextEditingController();
    final zoneCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nueva Estación"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nombre")),
            TextField(controller: zoneCtrl, decoration: const InputDecoration(labelText: "Zona")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              try {
                await ApiService.createStation(nameCtrl.text, zoneCtrl.text);
                if (mounted) Navigator.pop(context);
                _loadStations();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteStation(int id) async {
    try {
      await ApiService.deleteStation(id);
      _loadStations();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al eliminar: $e")));
      }
    }
  }

  Color _getSeverityColor(double? pm25) {
    if (pm25 == null) return Colors.grey;
    if (pm25 <= 12) return Colors.green;
    if (pm25 <= 35) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    if (ApiConfig.token == null) {
      return const Center(child: Text("Debes iniciar sesión para gestionar estaciones"));
    }
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStations,
              child: ListView.builder(
                itemCount: _stations.length,
                itemBuilder: (context, index) {
                  final station = _stations[index];
                  final pm25 = _latestPm25[station.id];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    color: _getSeverityColor(pm25).withOpacity(0.2),
                    child: ListTile(
                      title: Text(station.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Zona: ${station.zone}${pm25 != null ? ' | PM2.5: $pm25' : ' | Sin datos'}"),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteStation(station.id),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => StationDetailsScreen(station: station)),
                        ).then((_) => _loadStations());
                      },
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addStation,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class StationDetailsScreen extends StatefulWidget {
  final Station station;
  const StationDetailsScreen({super.key, required this.station});

  @override
  State<StationDetailsScreen> createState() => _StationDetailsScreenState();
}

class _StationDetailsScreenState extends State<StationDetailsScreen> {
  List<Emission> _emissions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadEmissions();
  }

  Future<void> _loadEmissions() async {
    setState(() { _isLoading = true; });
    try {
      final allEmissions = await ApiService.getEmissions();
      setState(() {
        _emissions = allEmissions.where((e) => e.stationId == widget.station.id).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al cargar emisiones: $e")));
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _addEmission() async {
    final pm25Ctrl = TextEditingController();
    final co2Ctrl = TextEditingController();
    final noxCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Registrar Emisión"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: pm25Ctrl, decoration: const InputDecoration(labelText: "PM2.5"), keyboardType: TextInputType.number),
            TextField(controller: co2Ctrl, decoration: const InputDecoration(labelText: "CO2"), keyboardType: TextInputType.number),
            TextField(controller: noxCtrl, decoration: const InputDecoration(labelText: "NOx"), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              try {
                await ApiService.createEmission(
                  widget.station.id,
                  double.tryParse(pm25Ctrl.text) ?? 0.0,
                  double.tryParse(co2Ctrl.text) ?? 0.0,
                  double.tryParse(noxCtrl.text) ?? 0.0,
                );
                if (mounted) Navigator.pop(context);
                _loadEmissions();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Emisiones - ${widget.station.name}"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadEmissions,
              child: ListView.builder(
                itemCount: _emissions.length,
                itemBuilder: (context, index) {
                  final e = _emissions[index];
                  // format date string if possible, or just show it
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: ListTile(
                      title: Text("Fecha: ${e.timestamp}"),
                      subtitle: Text("PM2.5: ${e.pm25} | CO2: ${e.co2} | NOx: ${e.nox}"),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEmission,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}