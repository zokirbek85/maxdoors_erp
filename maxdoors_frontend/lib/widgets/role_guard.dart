import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class RoleGuard extends StatelessWidget {
  final List<String> allow;
  final Widget child;
  const RoleGuard({super.key, required this.allow, required this.child});

  @override
  Widget build(BuildContext context) {
    final role = context.read<AuthProvider>().role ?? '';
    if (allow.contains(role)) return child;
    return Scaffold(
      appBar: AppBar(title: const Text('Access denied')),
      body: Center(
        child: Text(
          'Sizning rolingiz: $role. Bu sahifaga ruxsat yo‘q.',
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
