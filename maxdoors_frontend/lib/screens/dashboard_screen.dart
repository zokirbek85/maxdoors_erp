import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_drawer.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final role = authProvider.role ?? "unknown";

    return Scaffold(
      appBar: AppBar(
        title: const Text("MaxDoors ERP"),
        backgroundColor: const Color.fromARGB(255, 165, 133, 19),
        elevation: 0,
      ),
      drawer: AppDrawer(role: role),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color.fromARGB(255, 253, 254, 254),
              const Color.fromARGB(255, 255, 255, 255)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logotip
                Image.asset(
                  'assets/images/logo.png', // O'zingizning logotipingiz joylashgan manzilni ko'rsating
                  height: 150,
                ),
                const SizedBox(height: 32),
                // Xush kelibsiz xabari
                Text(
                  "Xush kelibsiz! Rolingiz: ${role.toUpperCase()}",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromRGBO(27, 20, 100, 1),
                  ),
                ),
                const SizedBox(height: 16),
                // Qisqacha tavsif
                const Text(
                  "MaxDoors ERP tizimiga muvaffaqiyatli kirdingiz.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 40),
                // Kirish tugmasi
                ElevatedButton(
                  onPressed: () {
                    // Dashboardga o'tish yoki boshqa kerakli harakat
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                    backgroundColor: const Color.fromRGBO(27, 20, 100, 1),
                  ),
                  child: const Text(
                    "Dashboardga o'tish",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
