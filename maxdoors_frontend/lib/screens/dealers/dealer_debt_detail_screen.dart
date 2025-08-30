import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/loading.dart';

class _Txn {
  final DateTime date;
  final String type; // 'order' | 'payment'
  final String ref;
  final double amountUsd; // order: +, payment: - (qarzni kamaytiradi)
  _Txn(
      {required this.date,
      required this.type,
      required this.ref,
      required this.amountUsd});
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
  double _opening = 0.0; // agar tarixiy start balans bo‘lsa shu yerga qo‘yasiz

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

      // -------- Orders (not canceled) ----------
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
            // total candidates
            final fs = [
              'total_usd',
              'grand_total_usd',
              'grand_total',
              'totalUSD',
              'total'
            ];
            double? tot;
            for (final f in fs) {
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

      // -------- Payments ----------
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
                date: dt, type: 'payment', ref: ref, amountUsd: -amt)); // minus
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
    // running balance
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
                            trailing: Text(_fmtUsd(_opening),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
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
                              color: color),
                          title: Text(
                              isOrder ? 'Buyurtma ${t.ref}' : 'To‘lov ${t.ref}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${t.date.toLocal()}'
                              .split('.')
                              .first
                              .replaceFirst('T', '  ')),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('$sign ${_fmtUsd(t.amountUsd.abs())}',
                                  style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold)),
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
