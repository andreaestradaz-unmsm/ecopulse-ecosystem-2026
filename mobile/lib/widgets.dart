// Widget raíz de navegación — define la estructura de pestañas de la aplicación
import 'package:flutter/material.dart';
import 'screens.dart';

// Controlador principal de pestañas: organiza las 3 secciones de la app en un TabBar
class MainTabController extends StatelessWidget {
  const MainTabController({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,  // Total de pestañas de navegación
      child: Scaffold(
        appBar: AppBar(
          title: const Text('EcoPulse'),
          backgroundColor: Colors.green,
          bottom: const TabBar(
            tabs: [
              // Pestaña 1: visualiza los datos ambientales en tiempo real
              Tab(icon: Icon(Icons.dashboard), text: "Monitoreo"),
              // Pestaña 2: gestiona estaciones (crear, listar, eliminar)
              Tab(icon: Icon(Icons.list_alt), text: "Gestión"),
              // Pestaña 3: configura la IP del backend e inicia/cierra sesión
              Tab(icon: Icon(Icons.settings), text: "Config"),
            ],
          ),
        ),
        // Cada pestaña carga su pantalla correspondiente
        body: const TabBarView(
          children: [
            HomeScreen(),
            ManagementScreen(),
            SettingsScreen(),
          ],
        ),
      ),
    );
  }
}