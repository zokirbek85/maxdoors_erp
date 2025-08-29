import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/loading.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _loading = true;
  String _error = '';
  int _products = 0;
  int _orders = 0;
  int _dealers = 0;
  int _payments = 0;

  Future<void> _fetchCounts() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final token = context.read<AuthProvider>().token!;
      Future<Map<String, dynamic>> countOf(String collection) async {
        final r = await ApiService.get(
          'collections/$collection/records?perPage=1',
          token: token,
        );
        return r;
      }

      final r1 = await countOf('products');
      final r2 = await countOf('orders');
      final r3 = await countOf('dealers');
      final r4 = await countOf('payments');

      setState(() {
        _products = (r1['totalItems'] as num).toInt();
        _orders = (r2['totalItems'] as num).toInt();
        _dealers = (r3['totalItems'] as num).toInt();
        _payments = (r4['totalItems'] as num).toInt();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchCounts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistika & Analitika'),
        actions: [
          IconButton(onPressed: _fetchCounts, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Loading(text: 'Yuklanmoqda...')
          : _error.isNotEmpty
          ? Center(child: Text('Xato: $_error'))
          : GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _tile('Mahsulotlar', _products),
                _tile('Buyurtmalar', _orders),
                _tile('Dillerlar', _dealers),
                _tile('To‘lovlar', _payments),
              ],
            ),
    );
  }

  Widget _tile(String title, int value) {
    return Card(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$value',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(title),
          ],
        ),
      ),
    );
  }
}
