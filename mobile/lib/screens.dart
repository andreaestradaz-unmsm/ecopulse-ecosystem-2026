// Pantallas de la aplicación móvil EcoPulse — cada clase es una vista completa
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'services.dart';
import 'models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen — Pestaña "Monitoreo": muestra los datos ambientales en tiempo real
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _ambientData;  // Último JSON recibido del backend
  bool _isLoading = false;
  String _statusMessage = "Cargando datos...";
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchData();
    // Refresca los datos automáticamente cada 5 segundos
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) _fetchData(showLoading: false);
    });
  }

  @override
  void dispose() {
    // Cancela el timer al salir de la pantalla para evitar memory leaks
    _timer?.cancel();
    super.dispose();
  }

  // Consulta el endpoint /app/datos_ambientales y actualiza el estado con los nuevos valores
  Future<void> _fetchData({bool showLoading = true}) async {
    if (showLoading) setState(() { _isLoading = true; });
    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/app/datos_ambientales");
      // Verifica que haya sesión activa antes de hacer la petición
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

  // Devuelve el color del indicador según el nivel de PM2.5 (OMS: verde/naranja/rojo)
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
            // Indicador de estado de la conexión con el backend
            Text(
              "Estado: $_statusMessage",
              style: TextStyle(color: _statusMessage == "Conectado al Backend" ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Tarjeta principal con el valor de PM2.5 de la estación más reciente
            Card(
              elevation: 4,
              color: _ambientData == null ? Colors.grey[200] : _getSeverityColor(pm25).withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Nombre de la estación activa
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        "ESTACIÓN: $station",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Muestra un spinner mientras carga o el valor grande de PM2.5
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
            // Fila de CO2
            ListTile(
              leading: const Icon(Icons.co2, color: Colors.blue, size: 40),
              title: const Text("Dióxido de Carbono (CO2)"),
              trailing: Text("${co2.toStringAsFixed(1)} ppm", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const Divider(),
            // Fila de NOx
            ListTile(
              leading: const Icon(Icons.science, color: Colors.purple, size: 40),
              title: const Text("Óxidos de Nitrógeno (NOx)"),
              trailing: Text("${nox.toStringAsFixed(1)} ppb", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
      // Botón para forzar una actualización manual
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchData,
        backgroundColor: Colors.green,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SettingsScreen — Pestaña "Config": configuración de IP y autenticación de usuario
// ─────────────────────────────────────────────────────────────────────────────
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
  bool _isRegister = false;  // true = modo registro, false = modo login

  // Envía la petición de login o registro según el modo activo
  Future<void> _submitAuth() async {
    final username = _userController.text.trim();
    final password = _passwordController.text.trim();
    if (username.isEmpty || password.isEmpty) {
      setState(() { _authMessage = "Completa todos los campos"; });
      return;
    }
    try {
      if (_isRegister) {
        // Modo registro: crea un nuevo usuario en el backend
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
        // Modo login: obtiene el JWT y lo guarda en ApiConfig para uso global
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
            // Campo para cambiar la IP del servidor backend en tiempo de ejecución
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(labelText: "IP de tu PC (Backend)", border: OutlineInputBorder()),
              onChanged: (val) { ApiConfig.serverIp = val.trim(); },
            ),
            const SizedBox(height: 20),
            // Si hay sesión activa, muestra el nombre y opción de cerrar sesión
            if (logged) ...[
              const Icon(Icons.check_circle, color: Colors.green, size: 60),
              const SizedBox(height: 10),
              Text("Sesión iniciada como: ${ApiConfig.userLogged}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ElevatedButton(
                // Cierra la sesión limpiando el token y el usuario del ApiConfig
                onPressed: () { setState(() { ApiConfig.token = null; ApiConfig.userLogged = null; _authMessage = "Sesión cerrada"; }); },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Cerrar Sesión", style: TextStyle(color: Colors.white)),
              )
            ] else ...[
              // Formulario de login o registro según el modo seleccionado
              Text(_isRegister ? "Registrar Usuario" : "Iniciar Sesión", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(controller: _userController, decoration: const InputDecoration(labelText: "Usuario", border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: "Contraseña", border: OutlineInputBorder())),
              const SizedBox(height: 16),
              if (_authMessage.isNotEmpty) Text(_authMessage, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _submitAuth, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: Text(_isRegister ? "Registrarse" : "Entrar", style: const TextStyle(color: Colors.white))),
              // Alterna entre modo login y modo registro
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

// ─────────────────────────────────────────────────────────────────────────────
// ManagementScreen — Pestaña "Gestión": lista y administra las estaciones
// ─────────────────────────────────────────────────────────────────────────────
class ManagementScreen extends StatefulWidget {
  const ManagementScreen({super.key});
  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen> {
  List<Station> _stations = [];
  Map<int, double> _latestPm25 = {};  // Mapa de station_id → último PM2.5 conocido
  bool _isLoading = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadStations();
    // Actualiza la lista de estaciones y sus valores cada 5 segundos
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) _loadStations(showLoading: false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Carga las estaciones y construye el mapa de último PM2.5 por estación
  Future<void> _loadStations({bool showLoading = true}) async {
    if (ApiConfig.token == null) return;
    if (showLoading) setState(() { _isLoading = true; });
    try {
      final stations = await ApiService.getStations();
      final emissions = await ApiService.getEmissions();

      // Obtiene la emisión más reciente por estación para mostrar su PM2.5 actual
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

  // Muestra un diálogo para ingresar nombre y zona de la nueva estación
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
            TextField(
              controller: nameCtrl,
              maxLength: 100,
              decoration: const InputDecoration(labelText: "Nombre de Estación", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: zoneCtrl,
              maxLength: 100,
              decoration: const InputDecoration(labelText: "Zona/Ubicación", border: OutlineInputBorder()),
            ),
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

  // Elimina la estación y recarga la lista actualizada
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

  // Retorna color según el nivel de contaminación para colorear las tarjetas de estaciones
  Color _getSeverityColor(double? pm25) {
    if (pm25 == null) return Colors.grey;
    if (pm25 <= 12) return Colors.green;
    if (pm25 <= 35) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    // Si no hay sesión, pide que el usuario inicie sesión primero
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
                    // El fondo de la tarjeta refleja la calidad del aire de esa estación
                    color: _getSeverityColor(pm25).withOpacity(0.2),
                    child: ListTile(
                      title: Text(station.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Zona: ${station.zone}${pm25 != null ? ' | PM2.5: $pm25' : ' | Sin datos'}"),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteStation(station.id),
                      ),
                      // Al tocar la tarjeta, navega al detalle de emisiones de esa estación
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
      // Botón para agregar una nueva estación al sistema
      floatingActionButton: FloatingActionButton(
        onPressed: _addStation,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// StationDetailsScreen — Subpantalla: historial de emisiones de una estación
// ─────────────────────────────────────────────────────────────────────────────
class StationDetailsScreen extends StatefulWidget {
  final Station station;
  const StationDetailsScreen({super.key, required this.station});

  @override
  State<StationDetailsScreen> createState() => _StationDetailsScreenState();
}

class _StationDetailsScreenState extends State<StationDetailsScreen> {
  List<Emission> _emissions = [];  // Lista de lecturas filtradas por esta estación
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadEmissions();
  }

  // Carga todas las emisiones y filtra sólo las que pertenecen a esta estación
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

  // Muestra un diálogo para registrar una lectura manual de PM2.5, CO2 y NOx
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
              // Lista de todas las lecturas registradas para esta estación
              child: ListView.builder(
                itemCount: _emissions.length,
                itemBuilder: (context, index) {
                  final e = _emissions[index];
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
      // Botón para registrar una lectura de emisión de forma manual
      floatingActionButton: FloatingActionButton(
        onPressed: _addEmission,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}