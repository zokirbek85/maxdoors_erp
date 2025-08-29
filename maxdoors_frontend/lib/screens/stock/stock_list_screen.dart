import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/product.dart';
import '../../widgets/loading.dart';

class StockListScreen extends StatefulWidget {
  const StockListScreen({super.key});

  @override
  State<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen> {
  bool _loading = true;
  String _error = '';
  List<Product> _items = [];

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final token = context.read<AuthProvider>().token!;
      final res = await ApiService.get(
        'collections/products/records?perPage=100&sort=name',
        token: token,
      );
      final items = (res['items'] as List)
          .map((e) => Product.fromJson(e))
          .toList();
      setState(() => _items = items);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ombor qoldiqlari'),
        actions: [
          IconButton(onPressed: _fetch, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Loading(text: 'Yuklanmoqda...')
          : _error.isNotEmpty
          ? Center(child: Text('Xato: $_error'))
          : ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final p = _items[i];
                return ListTile(
                  title: Text(p.name),
                  subtitle: Text(
                    'OK: ${p.stockOk} • DEFECT: ${p.stockDefect} • Price: \$${p.priceUsd}',
                  ),
                  trailing: Text(p.barcode ?? ''),
                );
              },
            ),
    );
  }
}
