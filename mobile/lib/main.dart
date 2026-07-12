import 'package:flutter/material.dart';
import 'widgets.dart';

void main() {
  runApp(const EcoPulseApp());
}

class EcoPulseApp extends StatelessWidget {
  const EcoPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EcoPulse Mobile',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const MainTabController(),
    );
  }
}