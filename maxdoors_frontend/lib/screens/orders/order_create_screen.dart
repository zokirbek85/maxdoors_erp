import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'order_detail_screen.dart';
import '../../widgets/async_dropdown.dart';

class OrderCreateScreen extends StatefulWidget {
  const OrderCreateScreen({super.key});

  @override
  State<OrderCreateScreen> createState() => _OrderCreateScreenState();
}

class _OrderCreateScreenState extends State<OrderCreateScreen> {
  String? _regionId;
  String? _dealerId;

  String discountType = 'none'; // none | percent | amount
  final discountValueCtrl = TextEditingController(text: '0');
  final noteCtrl = TextEditingController();
  bool loading = false;

  Future<List<Map<String, String>>> _fetchRegions() async {
    final auth = context.read<AuthProvider>();
    final res = await ApiService.get(
      'collections/regions/records?perPage=200&sort=name',
      token: auth.token,
    );
    final items = List<Map<String, dynamic>>.from(res['items'] as List);
    return items
        .map((e) => {
              'id': e['id'] as String,
              'label': (e['name'] ?? e['id']).toString(),
            })
        .toList();
  }

  Future<List<Map<String, String>>> _fetchDealers() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.userId ?? '';
    final role = auth.role;

    final filters = <String>[];
    if (role == 'manager') {
      filters.add("assigned_manager='$userId'");
    }
    if (_regionId != null && _regionId!.isNotEmpty) {
      filters.add("region='$_regionId'");
    }

    final filterQuery =
        filters.isEmpty ? '' : '&filter=${filters.join(' && ')}';
    final url = "collections/dealers/records?perPage=200&sort=name$filterQuery";
    final res = await ApiService.get(url, token: auth.token);
    final items = List<Map<String, dynamic>>.from(res['items'] as List);
    return items
        .map((e) => {
              'id': e['id'] as String,
              'label': (e['name'] ?? e['id']).toString(),
            })
        .toList();
  }

  Future<void> _create() async {
    if (_regionId == null || _dealerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Region va Dealer tanlang')),
      );
      return;
    }
    setState(() => loading = true);
    try {
      final auth = context.read<AuthProvider>();
      final body = {
        'region': _regionId,
        'dealer': _dealerId,
        'manager': auth.userId, // users.id
        'status': 'created', // default status
        'discount_type': discountType,
        'discount_value': double.tryParse(discountValueCtrl.text.trim()) ?? 0,
        'note': noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      };
      final r = await ApiService.post('collections/orders/records', body,
          token: auth.token);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: r['id'])),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Xato: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.read<AuthProvider>().role ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text("Buyurtma yaratish")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            AsyncDropdown(
              label: 'Region',
              value: _regionId,
              fetchOptions: _fetchRegions,
              onChanged: (v) => setState(() {
                _regionId = v;
                _dealerId = null; // region o‘zgarsa dealer qayta yuklanadi
              }),
            ),
            const SizedBox(height: 8),
            AsyncDropdown(
              label: role == 'manager' ? 'Mening dillerlarim' : 'Diller',
              value: _dealerId,
              fetchOptions: _fetchDealers,
              onChanged: (v) => setState(() => _dealerId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: discountType,
              items: const [
                DropdownMenuItem(value: 'none', child: Text('Chegirma yo‘q')),
                DropdownMenuItem(value: 'percent', child: Text('Chegirma (%)')),
                DropdownMenuItem(
                    value: 'amount', child: Text('Chegirma (USD)')),
              ],
              onChanged: (v) => setState(() => discountType = v ?? 'none'),
              decoration: const InputDecoration(labelText: 'Chegirma turi'),
            ),
            TextField(
              controller: discountValueCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Chegirma qiymati'),
            ),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Izoh (ixtiyoriy)'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: loading ? null : _create,
              child: Text(loading ? 'Kutilmoqda...' : 'Yaratish'),
            ),
          ],
        ),
      ),
    );
  }
}
