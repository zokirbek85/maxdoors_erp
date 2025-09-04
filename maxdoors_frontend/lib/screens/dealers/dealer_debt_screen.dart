import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/loading.dart';
import 'dealer_debt_detail_screen.dart';

class DealerDebtScreen extends StatefulWidget {
  const DealerDebtScreen({super.key});

  @override
  State<DealerDebtScreen> createState() => _DealerDebtScreenState();
}

class _DealerDebtScreenState extends State<DealerDebtScreen> {
  bool _loading = true;
  String _error = '';
  List<Map<String, dynamic>> _dealers = [];
  String _role = 'manager'; // default

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final auth = context.read<AuthProvider>();
      final token = auth.token!;
      final managerId = (auth.userId ?? '').trim();

      // 1) Rolni aniqlash: avval provider’dan, bo‘lmasa users/{id} dan o‘qiymiz
      _role = await _resolveRole(auth, token);

      // 2) Rolga qarab dillerlarni olish
      List<Map<String, dynamic>> dealers;
      if (_role == 'admin' || _role == 'accountant') {
        dealers = await _fetchAllDealers(token);
      } else {
        dealers = await _fetchDealersByManager(token, managerId);
      }

      // 3) Qarzdorlikni to‘ldirish (agar maydon bo‘lmasa — hisoblab beramiz)
      final out = <Map<String, dynamic>>[];
      for (final d in dealers) {
        final m = Map<String, dynamic>.from(d);
        final direct = _readDebtField(m);
        if (direct == null) {
          final debt = await _computeDealerDebtUsd(m['id'].toString(), token);
          m['_computed_debt_usd'] = debt;
        }
        out.add(m);
      }

      setState(() => _dealers = out);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// AuthProvider’da `role` bo‘lmasa, users/{id} dan olib kelamiz.
  Future<String> _resolveRole(AuthProvider auth, String token) async {
    final r = (auth.role ?? '').toString().trim().toLowerCase();
    if (r.isNotEmpty) return r;

    final uid = (auth.userId ?? '').trim();
    if (uid.isNotEmpty) {
      try {
        final u = await ApiService.get(
          "collections/users/records/$uid",
          token: token,
        );
        final role =
            (u['role'] ?? u['data']?['role'] ?? '').toString().toLowerCase();
        if (role.isNotEmpty) return role;
      } catch (_) {
        // bekor qilamiz, default manager bo‘ladi
      }
    }
    return 'manager';
  }

  // ===================== FETCH HELPERS =====================

  Future<List<Map<String, dynamic>>> _fetchAllDealers(String token) async {
    final out = <Map<String, dynamic>>[];
    int page = 1;
    while (true) {
      final url =
          "collections/dealers/records?perPage=200&page=$page&sort=name";
      final res = await ApiService.get(url, token: token);
      final items =
          List<Map<String, dynamic>>.from((res['items'] as List?) ?? const []);
      out.addAll(items);

      final total = (res['totalItems'] as num?)?.toInt() ?? out.length;
      if (out.length >= total || items.isEmpty) break;
      page++;
      if (page > 200) break; // guard
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> _fetchDealersByManager(
      String token, String managerId) async {
    final filters = <String>[
      "assigned_manager='$managerId'",
      "manager='$managerId'",
      "manager_id='$managerId'",
    ];

    Map<String, dynamic>? res;
    for (final f in filters) {
      try {
        final url =
            "collections/dealers/records?perPage=200&sort=name&filter=${Uri.encodeComponent(f)}";
        res = await ApiService.get(url, token: token);
        if ((res['items'] as List?)?.isNotEmpty == true) break;
      } catch (_) {}
    }

    return List<Map<String, dynamic>>.from(
        (res?['items'] as List?) ?? const []);
  }

  // ===================== DEBT UTILS =====================

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0.0;
  }

  double? _readDebtField(Map<String, dynamic> d) {
    for (final k in ['balance_usd', 'outstanding_usd', 'debt_usd']) {
      if (d.containsKey(k)) return _toDouble(d[k]);
    }
    return null;
  }

  String _fmtUsd(num v) => '\$${v.toStringAsFixed(2)}';

  Future<double> _computeDealerDebtUsd(String dealerId, String token) async {
    final ordersTotal = await _sumOrdersTotalUsd(dealerId, token);
    final paymentsTotal = await _sumPaymentsUsd(dealerId, token);
    final debt = ordersTotal - paymentsTotal;
    return debt.isNaN ? 0.0 : debt;
  }

  Future<double> _sumOrdersTotalUsd(String dealerId, String token) async {
    double sum = 0.0;
    int page = 1;
    final filter =
        "dealer='$dealerId' && (status!='canceled' && status!='cancelled')";
    while (true) {
      final url =
          "collections/orders/records?perPage=200&page=$page&filter=${Uri.encodeComponent(filter)}";
      final res = await ApiService.get(url, token: token);
      final items = (res['items'] as List?) ?? const [];
      if (items.isEmpty) break;

      for (final raw in items) {
        final o = raw as Map<String, dynamic>;
        final totalFields = [
          'total_usd',
          'grand_total_usd',
          'grand_total',
          'totalUSD',
          'total',
        ];
        double? tot;
        for (final f in totalFields) {
          if (o.containsKey(f)) {
            tot = _toDouble(o[f]);
            break;
          }
        }
        if (tot == null || tot == 0) {
          tot = await _calcOrderTotalFromItems(o['id'].toString(), token);
          final dt =
              (o['discountType'] ?? o['discount_type'] ?? 'none').toString();
          final dv = _toDouble(o['discountValue'] ?? o['discount_value']);
          if (dt == 'percent' && dv > 0) {
            tot = tot - (tot * dv / 100.0);
          } else if (dt == 'amount' && dv > 0) {
            tot = tot - dv;
          }
          if (tot < 0) tot = 0;
        }
        sum += tot ?? 0.0;
      }

      final total = (res['totalItems'] as num?)?.toInt() ?? items.length;
      if (page * 200 >= total) break;
      page++;
      if (page > 200) break;
    }
    return sum;
  }

  Future<double> _calcOrderTotalFromItems(String orderId, String token) async {
    double sum = 0.0;
    int page = 1;
    final filter = "order='$orderId'";
    while (true) {
      final url =
          "collections/order_items/records?perPage=200&page=$page&filter=${Uri.encodeComponent(filter)}";
      final res = await ApiService.get(url, token: token);
      final items = (res['items'] as List?) ?? const [];
      if (items.isEmpty) break;

      for (final it in items) {
        final m = it as Map<String, dynamic>;
        final qty = _toDouble(m['qty'] ?? m['quantity'] ?? m['amount']);
        final unit = _toDouble(
            m['unit_price_usd'] ?? m['price_usd'] ?? m['unitPriceUsd']);
        sum += qty * unit;
      }

      final total = (res['totalItems'] as num?)?.toInt() ?? items.length;
      if (page * 200 >= total) break;
      page++;
      if (page > 200) break;
    }

    return sum;
  }

  Future<double> _sumPaymentsUsd(String dealerId, String token) async {
    final collections = ['payments', 'dealer_payments', 'receipts'];
    final fields = ['amount_usd', 'amountUSD', 'amount', 'paid_usd'];

    for (final coll in collections) {
      try {
        double sum = 0.0;
        int page = 1;
        final filter = "dealer='$dealerId'";
        while (true) {
          final url =
              "collections/$coll/records?perPage=200&page=$page&filter=${Uri.encodeComponent(filter)}";
          final res = await ApiService.get(url, token: token);
          final items = (res['items'] as List?) ?? const [];
          if (items.isEmpty) break;

          for (final it in items) {
            final m = it as Map<String, dynamic>;
            double val = 0.0;
            for (final f in fields) {
              if (m.containsKey(f)) {
                val = _toDouble(m[f]);
                break;
              }
            }
            sum += val;
          }

          final total = (res['totalItems'] as num?)?.toInt() ?? items.length;
          if (page * 200 >= total) break;
          page++;
          if (page > 200) break;
        }
        return sum;
      } catch (_) {}
    }
    return 0.0;
  }

  void _openDetail(Map<String, dynamic> d) {
    final id = d['id'].toString();
    final name = (d['name'] ?? id).toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DealerDebtDetailScreen(dealerId: id, dealerName: name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleText = (_role == 'admin' || _role == 'accountant')
        ? "Barcha dillerlar — qarzdorlik"
        : "Mening dillerlarim — qarzdorlik";

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
        actions: [
          IconButton(onPressed: _fetch, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Loading(text: 'Yuklanmoqda...')
          : _error.isNotEmpty
              ? Center(child: Text('Xato: $_error'))
              : _dealers.isEmpty
                  ? const Center(child: Text("Diller topilmadi"))
                  : RefreshIndicator(
                      onRefresh: _fetch,
                      child: ListView.separated(
                        itemCount: _dealers.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final d = _dealers[i];
                          return ListTile(
                            onTap: () => _openDetail(d),
                            leading: const Icon(Icons.store),
                            title: Text(
                                d['name']?.toString() ?? d['id'].toString()),
                            subtitle:
                                Text('TIN: ${d['tin']?.toString() ?? '-'}'),
                            trailing: Text(
                              _fmtUsd(
                                _readDebtField(d) ??
                                    _toDouble(d['_computed_debt_usd']),
                              ),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
