// Punto de entrada de la aplicación móvil EcoPulse
import 'package:flutter/material.dart';
import 'widgets.dart';

// Inicia la app con el widget raíz EcoPulseApp
void main() {
  runApp(const EcoPulseApp());
}

// Widget raíz: configura el tema global y establece la pantalla inicial
class EcoPulseApp extends StatelessWidget {
  const EcoPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,  // Oculta la cinta "debug" en la esquina
      title: 'EcoPulse Mobile',
      theme: ThemeData(
        primarySwatch: Colors.green,  // Paleta verde acorde a la temática ambiental
        useMaterial3: true,
      ),
      // MainTabController es el controlador de las 3 pestañas principales
      home: const MainTabController(),
    );
  }
}