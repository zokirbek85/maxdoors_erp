import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';

// Orders
import '../screens/orders/order_create_screen.dart';
import '../screens/orders/orders_list_screen.dart';
import '../screens/orders/approval_queue_screen.dart';
import '../screens/orders/order_detail_screen.dart';
import '../screens/orders/order_item_add_screen.dart';

// Stock / Products
import '../screens/stock/stock_list_screen.dart';
import '../screens/stock/stock_entry_screen.dart';

// Payments / Reports / Debts
import '../screens/payments/payments_list_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/dealers/dealer_debt_screen.dart'; // ← MUHIM: bevosita import

// Regions & Dealers
import '../screens/regions/regions_list_screen.dart';
import '../screens/dealers/dealers_list_screen.dart' as dealers;

// Users (Admin CRUD)
import '../screens/users/users_list_screen.dart';

class AppDrawer extends StatelessWidget {
  final String role;
  const AppDrawer({super.key, required this.role});

  void _go(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Chiqish?'),
        content: const Text('Haqiqatan ham tizimdan chiqishni xohlaysizmi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_, false),
            child: const Text('Bekor'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(_, true),
            child: const Text('Chiqish'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await context.read<AuthProvider>().logout();
      if (Navigator.canPop(context)) Navigator.pop(context);
      // ignore: use_build_context_synchronously
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> items = [];

    if (role == "manager") {
      items.addAll([
        ListTile(
          leading: const Icon(Icons.receipt_long),
          title: const Text('Buyurtmalar'),
          onTap: () => _go(context, const OrdersListScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.add_shopping_cart),
          title: const Text("Buyurtma yaratish"),
          onTap: () => _go(context, const OrderCreateScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.inventory_2),
          title: const Text("Mahsulotlar qoldig‘i"),
          onTap: () => _go(context, const StockListScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.map),
          title: const Text("Regionlar (faqat ko‘rish)"),
          onTap: () => _go(context, const RegionsListScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.store_mall_directory),
          title: const Text("Dillerlar (faqat ko‘rish)"),
          onTap: () => _go(context, const dealers.DealersListScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.account_balance_wallet),
          title: const Text("Mening dillerlarim qarzdorligi"),
          onTap: () =>
              _go(context, const DealerDebtScreen()), // ← to‘g‘ridan-to‘g‘ri
        ),
      ]);
    } else if (role == "warehouseman") {
      items.addAll([
        ListTile(
          leading: const Icon(Icons.shopping_cart),
          title: const Text("Buyurtmalar ro‘yxati"),
          onTap: () => _go(context, const OrdersListScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.inventory_2),
          title: const Text("Mahsulotlar qoldig‘i"),
          onTap: () => _go(context, const StockListScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.add_box),
          title: const Text("Kirim (Stock Entry)"),
          onTap: () => _go(context, const StockEntryScreen()),
        ),
      ]);
    } else if (role == "accountant") {
      items.addAll([
        ListTile(
          leading: const Icon(Icons.shopping_cart_checkout),
          title: const Text("Buyurtmalar ro‘yxati"),
          onTap: () => _go(context, const OrdersListScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.payments),
          title: const Text("To‘lovlar"),
          onTap: () => _go(context, const PaymentsListScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.inventory_2),
          title: const Text("Mahsulotlar qoldig‘i"),
          onTap: () => _go(context, const StockListScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.add_box),
          title: const Text("Kirim (Stock Entry)"),
          onTap: () => _go(context, const StockEntryScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.map),
          title: const Text("Regionlar (CRUD)"),
          onTap: () => _go(context, const RegionsListScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.store_mall_directory),
          title: const Text("Dillerlar (CRUD)"),
          onTap: () => _go(context, const dealers.DealersListScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.bar_chart),
          title: const Text("Statistika & Analitika"),
          onTap: () => _go(context, const ReportsScreen()),
        ),
      ]);
    } else if (role == "admin") {
      items.addAll([
        ListTile(
          leading: const Icon(Icons.shopping_cart),
          title: const Text("Buyurtmalar ro‘yxati"),
          onTap: () => _go(context, const OrdersListScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.add_shopping_cart),
          title: const Text("Buyurtma yaratish"),
          onTap: () => _go(context, const OrderCreateScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.payments),
          title: const Text("To‘lovlar"),
          onTap: () => _go(context, const PaymentsListScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.inventory_2),
          title: const Text("Mahsulotlar qoldig‘i"),
          onTap: () => _go(context, const StockListScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.file_upload),
          title: const Text('Mahsulot importi'),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).pushNamed('/products/import');
          },
        ),
        ListTile(
          leading: const Icon(Icons.add_box),
          title: const Text("Kirim (Stock Entry)"),
          onTap: () => _go(context, const StockEntryScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.playlist_add_check),
          title: const Text('Qoldiq/Narx importi'),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).pushNamed('/products/stock_import');
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.group),
          title: const Text('Foydalanuvchilar (CRUD)'),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).pushNamed('/users');
          },
        ),
        ListTile(
          leading: const Icon(Icons.map),
          title: const Text("Regionlar (CRUD)"),
          onTap: () => _go(context, const RegionsListScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.store_mall_directory),
          title: const Text("Dillerlar (CRUD)"),
          onTap: () => _go(context, const dealers.DealersListScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.account_balance_wallet),
          title: const Text("Dillerlar qarzdorligi"),
          onTap: () =>
              _go(context, const DealerDebtScreen()), // ← to‘g‘ridan-to‘g‘ri
        ),
        ListTile(
          leading: const Icon(Icons.bar_chart),
          title: const Text("Statistika & Analitika"),
          onTap: () => _go(context, const ReportsScreen()),
        ),
      ]);
    } else if (role == "owner") {
      items.addAll([
        ListTile(
          leading: const Icon(Icons.bar_chart),
          title: const Text("Statistika & Analitika"),
          onTap: () => _go(context, const ReportsScreen()),
        ),
      ]);
    }

    items.add(const Divider(height: 1));
    items.add(
      ListTile(
        leading: const Icon(Icons.logout),
        title: const Text("Chiqish"),
        onTap: () => _logout(context),
      ),
    );

    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            child: Text(
              "MaxDoors ERP",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          ...items,
        ],
      ),
    );
  }
}
