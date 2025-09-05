import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/products/product_import_screen.dart';
import 'screens/products/product_stock_import_screen.dart';
import 'screens/users/users_list_screen.dart';
import 'screens/users/user_edit_screen.dart';
import 'screens/orders/approval_queue_screen.dart';

class MaxDoorsApp extends StatelessWidget {
  const MaxDoorsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'MaxDoors ERP',
            theme: ThemeData(primarySwatch: Colors.blue),
            home: auth.isAuthenticated
                ? const DashboardScreen()
                : const LoginScreen(),
            routes: {
              '/products/import': (ctx) => const ProductImportScreen(),
              '/products/stock_import': (ctx) =>
                  const ProductStockImportScreen(),
              '/users': (ctx) => const UsersListScreen(),
              '/users/edit': (ctx) => const UserEditScreen(),
              '/orders/approval_queue': (ctx) => const ApprovalQueueScreen(),
            },
          );
        },
      ),
    );
  }
}