import 'dart:typed_data';
import 'package:excel/excel.dart' as xlsx;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/loading.dart';

class _Txn {
  final DateTime date;
  final String type; // 'order' | 'payment'
  final String title; // Buyurtma 001-30.08.2025 yoki To‘lov <ref>
  final double amount; // order => +, payment => -
  double running;

  _Txn({
    required this.date,
    required this.type,
    required this.title,
    required this.amount,
    this.running = 0,
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
  final List<_Txn> _txns = [];
  double _opening = 0.0;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  // ---------------- helpers ----------------
  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0.0;
  }

  DateTime _parseDate(dynamic v) {
    if (v is String) {
      final d = DateTime.tryParse(v);
      if (d != null) return d.toLocal();
    }
    return DateTime.now();
  }

  String _fmtUsd(num v) => '\$${v.toStringAsFixed(2)}';

  String _fmtDaily(Map<String, dynamic> o) {
    final raw = (o['dailyNumber'] ?? o['number'] ?? o['id']).toString();
    int? seq;
    if (RegExp(r'^\d+$').hasMatch(raw)) {
      seq = int.tryParse(raw);
    } else {
      final m = RegExp(r'(\d{1,4})$').firstMatch(raw);
      if (m != null) seq = int.tryParse(m.group(1)!);
    }
    final dt = _parseDate(o['created'] ?? o['date']);
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    if (seq != null) return '${seq.toString().padLeft(3, '0')}-$dd.$mm.$yyyy';
    return '$raw-$dd.$mm.$yyyy';
  }

  Future<double> _calcOrderTotalFromItems(String orderId, String token) async {
    double sum = 0.0;
    int page = 1;
    while (true) {
      final url =
          "collections/order_items/records?perPage=200&page=$page&filter=${Uri.encodeComponent("order='$orderId'")}";
      final res = await ApiService.get(url, token: token);
      final items = (res['items'] as List?) ?? const [];
      if (items.isEmpty) break;

      for (final it in items) {
        final m = Map<String, dynamic>.from(it);
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

  // ---------------- fetch ----------------
  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = '';
      _txns.clear();
    });

    try {
      final token = context.read<AuthProvider>().token!;
      final dealerId = widget.dealerId;

      // Orders (canceled emas)
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

          for (final row in items) {
            final m = Map<String, dynamic>.from(row);
            double tot = _toDouble(m['total_usd'] ??
                m['grand_total_usd'] ??
                m['grand_total'] ??
                m['totalUSD'] ??
                m['total']);
            if (tot <= 0) {
              // itemlardan hisoblash
              tot = await _calcOrderTotalFromItems(m['id'].toString(), token);
              // chegirma
              final dt = (m['discountType'] ?? m['discount_type'] ?? 'none')
                  .toString();
              final dv = _toDouble(m['discountValue'] ?? m['discount_value']);
              if (dt == 'percent' && dv > 0) tot -= (tot * dv / 100.0);
              if (dt == 'amount' && dv > 0) tot -= dv;
              if (tot < 0) tot = 0;
            }

            final title = 'Buyurtma ${_fmtDaily(m)}';
            final date = _parseDate(m['created'] ?? m['date']);
            _txns.add(
                _Txn(date: date, type: 'order', title: title, amount: tot));
          }

          final total = (res['totalItems'] as num?)?.toInt() ?? items.length;
          if (page * 200 >= total) break;
          page++;
          if (page > 200) break;
        }
      }

      // Payments (bir nechta kolleksiya nomi bo‘lishi mumkin)
      Future<void> pullPay(String coll) async {
        int page = 1;
        final filter = "dealer='$dealerId'";
        while (true) {
          final url =
              "collections/$coll/records?perPage=200&page=$page&filter=${Uri.encodeComponent(filter)}";
          final res = await ApiService.get(url, token: token);
          final items = (res['items'] as List?) ?? const [];
          if (items.isEmpty) break;

          for (final row in items) {
            final m = Map<String, dynamic>.from(row);
            final amt = _toDouble(m['amount_usd'] ??
                m['amountUSD'] ??
                m['amount'] ??
                m['paid_usd']);
            final ref = (m['ref'] ?? m['id']).toString();
            final dt = _parseDate(m['created'] ?? m['date']);
            _txns.add(_Txn(
                date: dt, type: 'payment', title: 'To‘lov $ref', amount: -amt));
          }

          final total = (res['totalItems'] as num?)?.toInt() ?? items.length;
          if (page * 200 >= total) break;
          page++;
          if (page > 200) break;
        }
      }

      for (final c in ['payments', 'dealer_payments', 'receipts']) {
        try {
          await pullPay(c);
          break;
        } catch (_) {}
      }

      // sort va running
      _txns.sort((a, b) => a.date.compareTo(b.date));
      double cur = _opening;
      for (final t in _txns) {
        cur += t.amount;
        t.running = cur;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------- export Excel ----------------
  Future<void> _exportXlsx() async {
    try {
      if (_txns.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Ma’lumot yo‘q')));
        return;
      }

      final excel = xlsx.Excel.createExcel();
      final sh = excel['Debt'];

      // HEADER — const ishlatmaymiz
      final header = <xlsx.CellValue?>[
        xlsx.TextCellValue('DateTime'),
        xlsx.TextCellValue('Type'),
        xlsx.TextCellValue('Title'),
        xlsx.TextCellValue('Amount USD'),
        xlsx.TextCellValue('Running Balance USD'),
      ];
      sh.appendRow(header);

      // ROWS
      for (final t in _txns) {
        sh.appendRow(<xlsx.CellValue?>[
          xlsx.TextCellValue(
            '${t.date.toLocal()}'.split('.').first.replaceFirst('T', '  '),
          ),
          xlsx.TextCellValue(t.type),
          xlsx.TextCellValue(t.title),
          xlsx.DoubleCellValue(t.amount),
          xlsx.DoubleCellValue(t.running),
        ]);
      }

      final bytes = Uint8List.fromList(excel.encode()!);
      final fileName =
          'debt_${widget.dealerName}_${DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-')}.xlsx';

      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        mimeType: MimeType.microsoftExcel,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel eksport qilindi ($fileName)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Export xatosi: $e')));
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.dealerName} — qarzdorlik detali'),
        actions: [
          IconButton(onPressed: _fetch, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _exportXlsx, icon: const Icon(Icons.download)),
        ],
      ),
      body: _loading
          ? const Loading(text: 'Yuklanmoqda...')
          : _error.isNotEmpty
              ? Center(child: Text('Xato: $_error'))
              : _txns.isEmpty
                  ? const Center(child: Text('Ma’lumot yo‘q'))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
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
                        final isOrder = t.type == 'order';
                        final color = isOrder
                            ? Colors.red.shade700
                            : Colors.green.shade700;
                        final sign = isOrder ? '+' : '−';

                        return ListTile(
                          leading: Icon(
                              isOrder ? Icons.shopping_bag : Icons.payments,
                              color: color),
                          title: Text(t.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${t.date.toLocal()}'
                                .split('.')
                                .first
                                .replaceFirst('T', '  '),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('$sign ${_fmtUsd(t.amount.abs())}',
                                  style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('Qoldiq: ${_fmtUsd(t.running)}',
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
