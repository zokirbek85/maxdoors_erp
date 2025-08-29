import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../payments/payment_detail_screen.dart';
import '../../widgets/loading.dart';

class PaymentsListScreen extends StatefulWidget {
  const PaymentsListScreen({super.key});

  @override
  State<PaymentsListScreen> createState() => _PaymentsListScreenState();
}

class _PaymentsListScreenState extends State<PaymentsListScreen> {
  bool _loading = true;
  String _error = '';
  List<Map<String, dynamic>> _items = [];

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final token = context.read<AuthProvider>().token!;
      final res = await ApiService.get(
        'collections/payments/records?perPage=50&sort=-date',
        token: token,
      );
      setState(
        () => _items = List<Map<String, dynamic>>.from(res['items'] as List),
      );
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
        title: const Text('To‘lovlar'),
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
                  title: Text(
                    '${p['currency']} ${p['amount']}  •  ${p['method']}',
                  ),
                  subtitle: Text(
                    'Dealer: ${p['dealer']}  •  Sana: ${p['date']}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaymentDetailScreen(paymentId: p['id']),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
