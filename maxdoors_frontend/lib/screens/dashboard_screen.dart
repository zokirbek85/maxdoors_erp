import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_drawer.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final role = Provider.of<AuthProvider>(context).role ?? "unknown";

    return Scaffold(
      appBar: AppBar(title: const Text("MaxDoors ERP")),
      drawer: AppDrawer(role: role),
      body: Center(
        child: Text(
          "Xush kelibsiz! Rolingiz: $role",
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
