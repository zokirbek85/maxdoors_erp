import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class DealersListScreen extends StatefulWidget {
  const DealersListScreen({super.key});

  @override
  State<DealersListScreen> createState() => _DealersListScreenState();
}

class _DealersListScreenState extends State<DealersListScreen> {
  bool _loading = true;
  String _error = '';
  List<Map<String, dynamic>> _items = [];
  int _page = 1;
  final int _perPage = 50;
  int _total = 0;

  // dropdown ma'lumotlari
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _managers = [];

  // qidirish
  final _searchCtrl = TextEditingController();
  String _query = '';

  // Qarzdorliklar kesh: dealerId -> hisob-kitob
  final Map<String, _DebtCalc> _debts = {};
  final Set<String> _inFlight = {};

  bool get _canEdit {
    final role = context.read<AuthProvider>().role ?? '';
    return role == 'admin' || role == 'accountant';
  }

  @override
  void initState() {
    super.initState();
    _fetch(resetPage: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch({bool resetPage = false}) async {
    if (resetPage) _page = 1;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final token = context.read<AuthProvider>().token!;
      final sb = StringBuffer(
          'collections/dealers/records?perPage=$_perPage&page=$_page&sort=-created');

      if (_query.isNotEmpty) {
        final safe = _query.replaceAll("'", r"\'");
        final filter = "name~'$safe' || code~'$safe' || phone~'$safe'";
        sb.write('&filter=${Uri.encodeComponent(filter)}');
      }

      // expand label’lar uchun
      sb.write('&expand=region,manager');

      final res = await ApiService.get(sb.toString(), token: token);
      final items = List<Map<String, dynamic>>.from(res['items'] as List);
      setState(() {
        _items = items;
        _total = (res['totalItems'] as num?)?.toInt() ?? items.length;
      });

      // dropdownlar
      await _ensureDropdowns(token);

      // Qarzdorliklarni fon rejimida hisoblash
      _prefetchDebts(items.map((e) => e['id'].toString()).toList());
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _ensureDropdowns(String token) async {
    if (_regions.isEmpty) {
      final r = await ApiService.get(
        'collections/regions/records?perPage=200&sort=name',
        token: token,
      );
      _regions = List<Map<String, dynamic>>.from(r['items'] as List);
    }
    if (_managers.isEmpty) {
      final m = await ApiService.get(
        "collections/users/records?perPage=200&filter=${Uri.encodeComponent("role='manager'")}&sort=name",
        token: token,
      );
      _managers = List<Map<String, dynamic>>.from(m['items'] as List);
    }
  }

  String _expandName(Map<String, dynamic> row, String rel) {
    final exp = row['expand'];
    if (exp is Map && exp[rel] is Map && exp[rel]['name'] != null) {
      return exp[rel]['name'].toString();
    }
    return row[rel]?.toString() ?? '-';
  }

  // ---------- Qarzdorlik hisob-kitobi ----------
  Future<void> _prefetchDebts(List<String> dealerIds) async {
    const pool = 4;
    int i = 0;
    final futures = <Future<void>>[];
    while (i < dealerIds.length) {
      final slice = dealerIds.sublist(i, (i + pool).clamp(0, dealerIds.length));
      futures.add(Future.wait(slice.map(_ensureDebtCalculated)).then((_) {}));
      i += pool;
    }
    await Future.wait(futures);
  }

  Future<void> _ensureDebtCalculated(String dealerId) async {
    if (_debts.containsKey(dealerId) || _inFlight.contains(dealerId)) return;
    _inFlight.add(dealerId);
    try {
      final token = context.read<AuthProvider>().token!;

      // Orders
      final ordersRes = await ApiService.get(
        "collections/orders/records?perPage=200&filter=dealer='$dealerId'",
        token: token,
      );
      final orders = (ordersRes['items'] as List?) ?? const [];
      double ordersUsd = 0.0;
      for (final o in orders) {
        final orderId = o['id']?.toString() ?? '';
        final itemsRes = await ApiService.get(
          "collections/order_items/records?perPage=200&filter=order='$orderId'",
          token: token,
        );
        final items = (itemsRes['items'] as List?) ?? const [];
        double sub = 0.0;
        for (final it in items) {
          final qty = (it['qty'] is num)
              ? (it['qty'] as num).toDouble()
              : double.tryParse(it['qty']?.toString() ?? '0') ?? 0.0;
          final price = (it['unit_price_usd'] ?? it['unitPriceUsd']) is num
              ? (it['unit_price_usd'] ?? it['unitPriceUsd']).toDouble()
              : double.tryParse((it['unit_price_usd'] ?? it['unitPriceUsd'])
                          ?.toString() ??
                      '0') ??
                  0.0;
          sub += qty * price;
        }
        final discType =
            (o['discount_type'] ?? o['discountType'])?.toString() ?? 'none';
        final discVal = (o['discount_value'] ?? o['discountValue']) is num
            ? (o['discount_value'] ?? o['discountValue']).toDouble()
            : double.tryParse(
                    (o['discount_value'] ?? o['discountValue'])?.toString() ??
                        '0') ??
                0.0;
        double discount = 0.0;
        if (discType == 'percent') discount = sub * (discVal / 100.0);
        if (discType == 'amount') discount = discVal;
        ordersUsd += (sub - discount).clamp(0, double.infinity);
      }

      // Payments
      final paysRes = await ApiService.get(
        "collections/payments/records?perPage=200&filter=dealer='$dealerId'",
        token: token,
      );
      final pays = (paysRes['items'] as List?) ?? const [];
      double paysUsd = 0.0;
      for (final p in pays) {
        final currency = p['currency']?.toString().toUpperCase() ?? 'USD';
        final amount = (p['amount'] is num)
            ? (p['amount'] as num).toDouble()
            : double.tryParse(p['amount']?.toString() ?? '0') ?? 0.0;
        final fx = (p['fx_rate'] is num)
            ? (p['fx_rate'] as num).toDouble()
            : double.tryParse(p['fx_rate']?.toString() ?? '0') ?? 0.0;
        double usd;
        if (currency == 'UZS') {
          usd = fx > 0 ? amount / fx : 0.0;
        } else {
          usd = amount;
        }
        paysUsd += usd;
      }

      _debts[dealerId] = _DebtCalc(
        ordersUsd: ordersUsd,
        paymentsUsd: paysUsd,
        debtUsd: ordersUsd - paysUsd,
      );
      if (mounted) setState(() {});
    } catch (_) {
      // jim
    } finally {
      _inFlight.remove(dealerId);
    }
  }
  // ---------------------------------------------

  Future<void> _createOrEditDealer({Map<String, dynamic>? existing}) async {
    if (!_canEdit) return;

    final nameCtrl = TextEditingController(text: existing?['name']?.toString());
    final codeCtrl = TextEditingController(text: existing?['code']?.toString());
    final phoneCtrl =
        TextEditingController(text: existing?['phone']?.toString());
    final addressCtrl =
        TextEditingController(text: existing?['address']?.toString());
    String? regionId = existing?['region']?.toString();
    String? managerId = existing?['manager']?.toString();

    final formKey = GlobalKey<FormState>();
    final isEdit = existing != null;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Dillerni tahrirlash' : 'Yangi diller'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nomi *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Majburiy' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Code',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Telefon',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: regionId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Region *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _regions
                        .map((r) => DropdownMenuItem<String>(
                              value: r['id'].toString(),
                              child: Text(r['name']?.toString() ?? r['id']),
                            ))
                        .toList(),
                    onChanged: (v) => regionId = v,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Region tanlang' : null,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: managerId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Menejer *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _managers
                        .map((m) => DropdownMenuItem<String>(
                              value: m['id'].toString(),
                              child: Text(m['name']?.toString() ??
                                  m['email']?.toString() ??
                                  m['id']),
                            ))
                        .toList(),
                    onChanged: (v) => managerId = v,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Menejer tanlang' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: addressCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Manzil',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              try {
                final token = context.read<AuthProvider>().token!;
                final payload = {
                  'name': nameCtrl.text.trim(),
                  'code': codeCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'address': addressCtrl.text.trim(),
                  'region': regionId,
                  'manager': managerId,
                };

                if (isEdit) {
                  await ApiService.patch(
                    'collections/dealers/records/${existing!['id']}',
                    payload,
                    token: token,
                  );
                } else {
                  await ApiService.post(
                    'collections/dealers/records',
                    payload,
                    token: token,
                  );
                }

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          isEdit ? 'Diller yangilandi' : 'Diller yaratildi'),
                    ),
                  );
                  _fetch();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Xato: $e')),
                );
              }
            },
            child: Text(isEdit ? 'Saqlash' : 'Yaratish'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDealer(Map<String, dynamic> row) async {
    if (!_canEdit) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('O‘chirish?'),
        content: Text("“${row['name'] ?? row['id']}” dillerini o‘chirasizmi?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(_, false),
              child: const Text('Yo‘q')),
          ElevatedButton(
              onPressed: () => Navigator.pop(_, true), child: const Text('Ha')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final token = context.read<AuthProvider>().token!;
      await ApiService.delete('collections/dealers/records/${row['id']}',
          token: token);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('O‘chirildi')));
        _fetch();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Xato: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dillerlar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetch(resetPage: true),
            tooltip: 'Yangilash',
          ),
          if (_canEdit)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _createOrEditDealer(),
              tooltip: 'Yangi diller',
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Qidirish (nom / code / telefon)',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) {
                      _query = _searchCtrl.text.trim();
                      _fetch(resetPage: true);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _query = _searchCtrl.text.trim();
                    _fetch(resetPage: true);
                  },
                  child: const Text('Qidirish'),
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Xato: $_error',
                  style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: _items.isEmpty && !_loading
                ? const Center(child: Text('Dillerlar topilmadi'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final it = _items[i];
                      final id = it['id'].toString();
                      final name = (it['name'] ?? '').toString();
                      final code = (it['code'] ?? '').toString();
                      final phone = (it['phone'] ?? '').toString();
                      final region = _expandName(it, 'region');
                      final manager = _expandName(it, 'manager');

                      final calc = _debts[id];

                      // debt rangi
                      final Color debtColor;
                      if (calc == null) {
                        debtColor = Theme.of(context).hintColor;
                      } else if (calc.debtUsd > 1e-6) {
                        debtColor = Colors.red.shade600;
                      } else if (calc.debtUsd < -1e-6) {
                        debtColor = Colors.green.shade700; // avans
                      } else {
                        debtColor = Theme.of(context).colorScheme.primary;
                      }

                      return Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.blueGrey.withOpacity(0.2)),
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.store)),
                          title: Text(
                            name.isEmpty ? '-' : name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (code.isNotEmpty) Text('Code: $code'),
                              if (phone.isNotEmpty) Text('Tel: $phone'),
                              Text('Region: $region • Manager: $manager'),
                              if (calc != null)
                                Text(
                                  'Buyurtmalar: \$${calc.ordersUsd.toStringAsFixed(2)}  •  To‘lovlar: \$${calc.paymentsUsd.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                  ),
                                )
                              else
                                const Text('Qarzdorlik hisoblanmoqda…'),
                            ],
                          ),
                          // ⬇️ Qarzdorlik + (ixtiyoriy) menyu birga
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (calc == null)
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              else
                                Text(
                                  '\$${calc.debtUsd.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: debtColor,
                                  ),
                                ),
                              if (_canEdit) ...[
                                const SizedBox(width: 6),
                                PopupMenuButton<String>(
                                  onSelected: (v) {
                                    if (v == 'edit') {
                                      _createOrEditDealer(existing: it);
                                    } else if (v == 'delete') {
                                      _deleteDealer(it);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, size: 18),
                                          SizedBox(width: 8),
                                          Text('Tahrirlash'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete,
                                              size: 18, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('O‘chirish'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          onLongPress: _canEdit
                              ? () => _createOrEditDealer(existing: it)
                              : null,
                        ),
                      );
                    },
                  ),
          ),
          if (_total > _perPage)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _page > 1
                        ? () {
                            setState(() => _page--);
                            _fetch();
                          }
                        : null,
                    child: const Text('Oldingi'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('$_page'),
                  ),
                  TextButton(
                    onPressed: (_page * _perPage) < _total
                        ? () {
                            setState(() => _page++);
                            _fetch();
                          }
                        : null,
                    child: const Text('Keyingi'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DebtCalc {
  final double ordersUsd;
  final double paymentsUsd;
  final double debtUsd;

  _DebtCalc({
    required this.ordersUsd,
    required this.paymentsUsd,
    required this.debtUsd,
  });
}
