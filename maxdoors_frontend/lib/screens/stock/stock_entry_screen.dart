import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class StockEntryScreen extends StatefulWidget {
  const StockEntryScreen({super.key});

  @override
  State<StockEntryScreen> createState() => _StockEntryScreenState();
}

class _StockEntryScreenState extends State<StockEntryScreen> {
  final supplierCtrl = TextEditingController(); // supplier id
  final productCtrl = TextEditingController(); // product id
  final qtyCtrl = TextEditingController(text: '1');
  final priceCtrl = TextEditingController(text: '0');
  final dateCtrl = TextEditingController(); // YYYY-MM-DD
  String currency = 'USD';
  String note = '';
  bool loading = false;

  Future<void> _submit() async {
    setState(() => loading = true);
    try {
      final token = context.read<AuthProvider>().token!;
      final date = (dateCtrl.text.isEmpty)
          ? DateTime.now().toIso8601String().substring(0, 10)
          : dateCtrl.text;

      // 1) Create stock entry
      final entry = await ApiService.post('collections/stock_entries/records', {
        'supplier': supplierCtrl.text.trim(),
        'date': date,
        'currency': currency,
        'rate': currency == 'USD' ? 1 : 0, // hook to fill, can be 0
        'note': note,
      }, token: token);

      // 2) Create item
      await ApiService.post('collections/stock_entry_items/records', {
        'entry': entry['id'],
        'product': productCtrl.text.trim(),
        'qty': double.tryParse(qtyCtrl.text.trim()) ?? 1,
        'price': double.tryParse(priceCtrl.text.trim()) ?? 0,
        'is_defect': false,
      }, token: token);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Kirim saqlandi')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Xato: $e')));
      }
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kirim (purchase)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: supplierCtrl,
              decoration: const InputDecoration(labelText: 'Supplier ID'),
            ),
            TextField(
              controller: productCtrl,
              decoration: const InputDecoration(labelText: 'Product ID'),
            ),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Miqdor'),
            ),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Narx (entry currency)',
              ),
            ),
            TextField(
              controller: dateCtrl,
              decoration: const InputDecoration(
                labelText: 'Sana (YYYY-MM-DD, ixtiyoriy)',
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: currency,
              items: const [
                DropdownMenuItem(value: 'USD', child: Text('USD')),
                DropdownMenuItem(value: 'UZS', child: Text('UZS')),
              ],
              onChanged: (v) => setState(() => currency = v ?? 'USD'),
              decoration: const InputDecoration(labelText: 'Valyuta'),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(labelText: 'Izoh (ixtiyoriy)'),
              onChanged: (v) => note = v,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: loading ? null : _submit,
              child: Text(loading ? 'Kutilmoqda...' : 'Saqlash'),
            ),
          ],
        ),
      ),
    );
  }
}
