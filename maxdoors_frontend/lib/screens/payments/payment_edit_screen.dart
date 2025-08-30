import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class PaymentEditScreen extends StatefulWidget {
  final Map<String, dynamic> payment; // to‘liq item

  const PaymentEditScreen({super.key, required this.payment});

  @override
  State<PaymentEditScreen> createState() => _PaymentEditScreenState();
}

class _PaymentEditScreenState extends State<PaymentEditScreen> {
  final _formKey = GlobalKey<FormState>();

  // form fields
  String? _dealerId; // Dropdown uchun null bo‘lishi mumkin
  DateTime _date = DateTime.now();
  final _amountCtrl = TextEditingController();
  String _currency = 'USD'; // USD | UZS
  String _method = 'cash'; // cash | card | bank
  final _noteCtrl = TextEditingController();

  bool _loading = false;
  String _error = '';

  // dropdown data (qat'iy String xarita)
  List<Map<String, String>> _dealers = <Map<String, String>>[];

  // kurs
  static const String EXCHANGE_COLLECTION = 'exchange_rates'; // moslang
  double _latestRate = 1.0; // USD->UZS

  String get _id => (widget.payment['id'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _prefill();
    _bootstrap();
  }

  void _prefill() {
    final p = widget.payment;
    _dealerId = p['dealer']?.toString();
    // sana
    final rawDate = (p['date'] ?? p['created'])?.toString();
    if (rawDate != null && rawDate.isNotEmpty) {
      try {
        _date = DateTime.parse(rawDate);
      } catch (_) {}
    }
    _amountCtrl.text = (p['amount'] as num?)?.toString() ?? '';
    _currency = (p['currency']?.toString().isNotEmpty ?? false)
        ? p['currency'].toString()
        : 'USD';
    _method = (p['method']?.toString().isNotEmpty ?? false)
        ? p['method'].toString()
        : 'cash';
    _noteCtrl.text = p['note']?.toString() ?? '';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      setState(() => _loading = true);
      final token = context.read<AuthProvider>().token!;
      // dealers
      final dRes = await ApiService.get(
        'collections/dealers/records?perPage=200&sort=name',
        token: token,
      );
      final items = (dRes['items'] as List?) ?? const [];
      _dealers = items.map<Map<String, String>>((e) {
        final id = (e['id'] ?? '').toString();
        final label = (e['name'] ?? id).toString();
        return {'id': id, 'label': label};
      }).toList();

      // latest exchange rate
      try {
        final rRes = await ApiService.get(
          'collections/$EXCHANGE_COLLECTION/records?perPage=1&sort=-date',
          token: token,
        );
        final rItems = (rRes['items'] as List?) ?? const [];
        if (rItems.isNotEmpty) {
          final it = rItems.first as Map<String, dynamic>;
          final rate = (it['rate'] as num?)?.toDouble();
          if (rate != null && rate > 0) _latestRate = rate;
        }
      } catch (_) {}
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dealerId == null || _dealerId!.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Diller tanlang.')));
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final token = context.read<AuthProvider>().token!;
      final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;

      // USDga qayta hisob
      final rate = _latestRate <= 0 ? 1.0 : _latestRate;
      final amountUsd = _currency == 'USD' ? amount : (amount / rate);

      final body = <String, dynamic>{
        'dealer': _dealerId!, // PATCH uchun String talab qilinadi
        'date': _date.toIso8601String(),
        'amount': amount,
        'currency': _currency,
        'method': _method,
        'note': _noteCtrl.text.trim(),
        'rate': rate,
        'amount_usd': double.parse(amountUsd.toStringAsFixed(2)),
      };

      await ApiService.patch('collections/payments/records/$_id', body,
          token: token);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saqlangan')));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null) {
      setState(() => _date = DateTime(
            picked.year,
            picked.month,
            picked.day,
            _date.hour,
            _date.minute,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sana matni (readOnly field uchun)
    final dateText =
        '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

    final dealerItems = _dealers.map<DropdownMenuItem<String>>((d) {
      final id = d['id'] ?? ''; // KAFOLAT: String
      final label = d['label'] ?? id;
      return DropdownMenuItem<String>(
        value: id, // <-- String (NOT String?)
        child: Text(label),
      );
    }).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('To‘lovni tahrirlash'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    if (_error.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('Xato: $_error',
                            style: const TextStyle(color: Colors.red)),
                      ),

                    // Dealer
                    DropdownButtonFormField<String>(
                      value: _dealerId, // bu T? bo‘lishi mumkin (norm)
                      items: dealerItems,
                      onChanged: (v) => setState(() => _dealerId = v),
                      decoration: const InputDecoration(
                        labelText: 'Diller',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Tanlang' : null,
                    ),
                    const SizedBox(height: 12),

                    // Date
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            readOnly: true,
                            controller: TextEditingController(text: dateText),
                            decoration: const InputDecoration(
                              labelText: 'Sana',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.date_range),
                          label: const Text('Tanlash'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Amount + Currency
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                signed: false, decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Miqdor',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: (v) {
                              final d = double.tryParse((v ?? '').trim());
                              if (d == null || d <= 0) return 'Miqdor xato';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 120,
                          child: DropdownButtonFormField<String>(
                            value: _currency,
                            items: const [
                              DropdownMenuItem(
                                  value: 'USD', child: Text('USD')),
                              DropdownMenuItem(
                                  value: 'UZS', child: Text('UZS')),
                            ],
                            onChanged: (v) =>
                                setState(() => _currency = v ?? 'USD'),
                            decoration: const InputDecoration(
                              labelText: 'Valyuta',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Joriy kurs (USD→UZS): $_latestRate',
                        style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 12),

                    // Method
                    DropdownButtonFormField<String>(
                      value: _method,
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('Naqd')),
                        DropdownMenuItem(value: 'card', child: Text('Karta')),
                        DropdownMenuItem(value: 'bank', child: Text('Bank')),
                      ],
                      onChanged: (v) => setState(() => _method = v ?? 'cash'),
                      decoration: const InputDecoration(
                        labelText: 'To‘lov turi',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Note
                    TextField(
                      controller: _noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Izoh (ixtiyoriy)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    ElevatedButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.save),
                      label: const Text('Saqlash'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
