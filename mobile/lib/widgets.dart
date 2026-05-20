import 'package:flutter/material.dart';
import 'screens.dart';

class MainTabController extends StatelessWidget {
  const MainTabController({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('EcoPulse'),
          backgroundColor: Colors.green,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: "Monitoreo"),
              Tab(icon: Icon(Icons.settings), text: "Config"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            HomeScreen(),
            SettingsScreen(),
          ],
        ),
      ),
    );
  }
}