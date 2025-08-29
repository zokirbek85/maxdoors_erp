import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/loading.dart';

class PaymentDetailScreen extends StatefulWidget {
  final String paymentId;
  const PaymentDetailScreen({super.key, required this.paymentId});

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen> {
  bool _loading = true;
  String _error = '';
  Map<String, dynamic>? _payment;
  List<Map<String, dynamic>> _allocs = [];

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final token = context.read<AuthProvider>().token!;
      final p = await ApiService.get(
        'collections/payments/records/${widget.paymentId}',
        token: token,
      );
      final a = await ApiService.get(
        "collections/payment_applications/records?filter=payment='${widget.paymentId}'&perPage=100",
        token: token,
      );
      setState(() {
        _payment = p;
        _allocs = List<Map<String, dynamic>>.from(a['items'] as List);
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
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('To‘lov detali')),
      body: _loading
          ? const Loading(text: 'Yuklanmoqda...')
          : _error.isNotEmpty
          ? Center(child: Text('Xato: $_error'))
          : _payment == null
          ? const Center(child: Text('Topilmadi'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'To‘lov: ${_payment!['currency']} ${_payment!['amount']}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text('Dealer: ${_payment!['dealer']}'),
                Text('Sana: ${_payment!['date']}'),
                if (_payment!['fx_rate'] != null)
                  Text('FX: ${_payment!['fx_rate']}'),
                if (_payment!['note'] != null &&
                    (_payment!['note'] as String).isNotEmpty)
                  Text('Izoh: ${_payment!['note']}'),
                const SizedBox(height: 12),
                const Divider(),
                const Text(
                  'Taqsimotlar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._allocs.map(
                  (x) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Order: ${x['order']}'),
                    subtitle: Text(
                      'Amount in pay curr: ${x['amount_in_payment_currency']}',
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
