import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/loading.dart';

/// =========================
///  DETAIL: DealerDebtDetail
/// =========================
class _Txn {
  final DateTime date;
  final String type; // 'order' | 'payment'
  final String ref;
  final double amountUsd; // order: +, payment: - (qarzni kamaytiradi)
  _Txn({
    required this.date,
    required this.type,
    required this.ref,
    required this.amountUsd,
  });
}

class DealerDebtDetailScreen extends StatefulWidget {
  final String dealerId;
  final String dealerName;
  const DealerDebtDetailScreen({
    super.key,
    required this.dealerId,
    required this.dealerName,
  });

  @override
  State<DealerDebtDetailScreen> createState() => _DealerDebtDetailScreenState();
}

class _DealerDebtDetailScreenState extends State<DealerDebtDetailScreen> {
  bool _loading = true;
  String _error = '';
  List<_Txn> _txns = [];
  double _opening = 0.0;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0.0;
  }

  DateTime _parseDate(dynamic v) {
    if (v is String) {
      final d = DateTime.tryParse(v);
      if (d != null) return d;
    }
    return DateTime.now();
  }

  String _fmtUsd(num v) => '\$${v.toStringAsFixed(2)}';

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final token = context.read<AuthProvider>().token!;
      final dealerId = widget.dealerId;
      final txns = <_Txn>[];

      // Orders (not canceled)
      {
        int page = 1;
        final filter =
            "dealer='$dealerId' && (status!='canceled' && status!='cancelled')";
        while (true) {
          final url =
              "collections/orders/records?perPage=200&page=$page&filter=${Uri.encodeComponent(filter)}";
          final res = await ApiService.get(url, token: token);
          final items = (res['items'] as List?) ?? const [];
          if (items.isEmpty) break;

          for (final o in items) {
            final m = o as Map<String, dynamic>;
            final totalFields = [
              'total_usd',
              'grand_total_usd',
              'grand_total',
              'totalUSD',
              'total'
            ];
            double? tot;
            for (final f in totalFields) {
              if (m.containsKey(f)) {
                tot = _toDouble(m[f]);
                break;
              }
            }
            tot ??= 0.0;

            final ref = (m['dailyNumber'] ??
                    m['number'] ??
                    m['daily_number'] ??
                    m['id'])
                .toString();
            final dt = _parseDate(m['created'] ?? m['ts'] ?? m['date']);

            txns.add(_Txn(date: dt, type: 'order', ref: ref, amountUsd: tot));
          }

          final total = (res['totalItems'] as num?)?.toInt() ?? items.length;
          if (page * 200 >= total) break;
          page++;
          if (page > 200) break;
        }
      }

      // Payments
      Future<void> pull(String coll) async {
        int page = 1;
        final filter = "dealer='$dealerId'";
        while (true) {
          final url =
              "collections/$coll/records?perPage=200&page=$page&filter=${Uri.encodeComponent(filter)}";
          final res = await ApiService.get(url, token: token);
          final items = (res['items'] as List?) ?? const [];
          if (items.isEmpty) break;

          for (final p in items) {
            final m = p as Map<String, dynamic>;
            double amt = 0.0;
            for (final f in ['amount_usd', 'amountUSD', 'amount', 'paid_usd']) {
              if (m.containsKey(f)) {
                amt = _toDouble(m[f]);
                break;
              }
            }
            final ref = (m['ref'] ?? m['id']).toString();
            final dt = _parseDate(m['created'] ?? m['ts'] ?? m['date']);
            txns.add(_Txn(
              date: dt,
              type: 'payment',
              ref: ref,
              amountUsd: -amt, // minus = qarzni kamaytiradi
            ));
          }

          final total = (res['totalItems'] as num?)?.toInt() ?? items.length;
          if (page * 200 >= total) break;
          page++;
          if (page > 200) break;
        }
      }

      for (final c in ['payments', 'dealer_payments', 'receipts']) {
        try {
          await pull(c);
          break;
        } catch (_) {}
      }

      txns.sort((a, b) => a.date.compareTo(b.date));
      setState(() => _txns = txns);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Running balance
    final running = <double>[];
    double cur = _opening;
    for (final t in _txns) {
      cur += t.amountUsd;
      running.add(cur);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.dealerName} — qarzdorlik detali'),
        actions: [
          IconButton(onPressed: _fetch, icon: const Icon(Icons.refresh))
        ],
      ),
      body: _loading
          ? const Loading(text: 'Yuklanmoqda...')
          : _error.isNotEmpty
              ? Center(child: Text('Xato: $_error'))
              : _txns.isEmpty
                  ? const Center(child: Text('Ma’lumot yo‘q'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _txns.length + 1,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          return ListTile(
                            leading: const Icon(Icons.flag),
                            title: const Text('Boshlang‘ich qoldiq'),
                            trailing: Text(
                              _fmtUsd(_opening),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          );
                        }
                        final t = _txns[i - 1];
                        final bal = running[i - 1];
                        final isOrder = t.type == 'order';
                        final color = isOrder
                            ? Colors.red.shade700
                            : Colors.green.shade700;
                        final sign = isOrder ? '+' : '−';
                        return ListTile(
                          leading: Icon(
                            isOrder ? Icons.shopping_bag : Icons.payments,
                            color: color,
                          ),
                          title: Text(
                            isOrder ? 'Buyurtma ${t.ref}' : 'To‘lov ${t.ref}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text('${t.date.toLocal()}'
                              .split('.')
                              .first
                              .replaceFirst('T', '  ')),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$sign ${_fmtUsd(t.amountUsd.abs())}',
                                style: TextStyle(
                                    color: color, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text('Qoldiq: ${_fmtUsd(bal)}',
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}

/// =========================
///  LIST: DealerDebtScreen
/// =========================
class DealerDebtScreen extends StatefulWidget {
  const DealerDebtScreen({super.key});

  @override
  State<DealerDebtScreen> createState() => _DealerDebtScreenState();
}

class _DealerDebtScreenState extends State<DealerDebtScreen> {
  bool _loading = true;
  String _error = '';
  List<Map<String, dynamic>> _dealers = [];

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
          break;
        } catch (_) {}
      }

      final dealers =
          List<Map<String, dynamic>>.from((res?['items'] as List?) ?? const []);

      // Har bir diller uchun qarzdorlikni aniqlash
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

  // helpers
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

  String _fmtDebt(Map<String, dynamic> d) {
    final direct = _readDebtField(d);
    final debt = direct ?? _toDouble(d['_computed_debt_usd']);
    return _fmtUsd(debt);
  }

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
          final dt = (o['discountType'] ?? o['discount_type'] ?? 'none')
              .toString()
              .toLowerCase();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mening dillerlarim — qarzdorlik"),
        actions: [
          IconButton(onPressed: _fetch, icon: const Icon(Icons.refresh))
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
