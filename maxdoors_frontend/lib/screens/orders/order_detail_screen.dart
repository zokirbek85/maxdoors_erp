import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/order.dart';
import '../../widgets/loading.dart';
import 'order_item_add_screen.dart';
import '../../services/pdf_service.dart';

// ===== Helpers to safely read dynamic Order fields =====
String? _getStr(dynamic v) => v == null ? null : v.toString();

String? _humanIdAny(Order o) {
  final d = o as dynamic;
  dynamic v;
  try {
    v = d.humanId;
  } catch (_) {}
  if (v == null) {
    try {
      v = d.human_id;
    } catch (_) {}
  }
  final s = _getStr(v)?.trim();
  return (s == null || s.isEmpty) ? null : s;
}

dynamic _dailySeqAny(Order o) {
  final d = o as dynamic;
  dynamic v;
  try {
    v = d.dailySeq;
  } catch (_) {}
  if (v == null) {
    try {
      v = d.daily_seq;
    } catch (_) {}
  }
  if (v == null) {
    try {
      v = d.dailyNumber;
    } catch (_) {}
  }
  if (v == null) {
    try {
      v = d.daily_number;
    } catch (_) {}
  }
  return v;
}

// Uzbek labels for statuses
String _statusUz(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'created':
      return 'Yangi';
    case 'edit_requested':
      return "O'zgartirish so‘ralgan";
    case 'editable':
      return "O'zgartirish mumkin";
    case 'packed':
      return 'Yig‘ilgan';
    case 'shipped':
      return 'Jo‘natilgan';
    default:
      return '-';
  }
}

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _loading = true;
  String _error = '';
  Order? _order;
  List<OrderItem> _items = [];

  double get _subtotalUsd {
    double s = 0;
    for (final it in _items) {
      s += (it.unitPriceUsd ?? 0) * (it.qty ?? 0);
    }
    return s;
  }

  double get _discountUsd {
    if (_order == null) return 0;
    final t = _order!.discountType ?? 'none';
    final v = _order!.discountValue ?? 0;
    if (t == 'percent') return (_subtotalUsd * v) / 100.0;
    if (t == 'amount') return v;
    return 0;
  }

  double get _totalUsd =>
      (_subtotalUsd - _discountUsd).clamp(0, double.infinity);

  // ---- roles ----
  bool get _isManager => (context.read<AuthProvider>().role ?? '') == 'manager';
  bool get _isWarehouse =>
      (context.read<AuthProvider>().role ?? '') == 'warehouseman';
  bool get _isAdminOrAcc {
    final r = context.read<AuthProvider>().role ?? '';
    return r == 'admin' || r == 'accountant';
  }

  /// Manager (yoki admin/accountant) CREATED yoki EDITABLE holatda item qo‘sha oladi
  bool get _canEditItems {
    if (_order == null) return false;
    final st = _order!.status ?? '';
    final canRole = _isManager || _isAdminOrAcc;
    return canRole && (st == 'created' || st == 'editable');
  }

  /// Edit so‘rash faqat PACKED dan keyin (manager)
  bool get _canRequestEdit {
    if (_order == null) return false;
    final st = _order!.status ?? '';
    return _isManager && st == 'packed';
  }

  /// EDITABLE → CREATED (manager/admin/accountant)
  bool get _canResendToWarehouse {
    if (_order == null) return false;
    final st = _order!.status ?? '';
    return (_isManager || _isAdminOrAcc) && st == 'editable';
  }

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
      final token = context.read<AuthProvider>().token!;
      final oRes = await ApiService.get(
        'collections/orders/records/${widget.orderId}?expand=dealer,region,manager,warehouse',
        token: token,
      );
      final oiRes = await ApiService.get(
        "collections/order_items/records?filter=order='${widget.orderId}'&perPage=200&expand=product",
        token: token,
      );
      setState(() {
        _order = Order.fromJson(oRes);
        _items =
            (oiRes['items'] as List).map((e) => OrderItem.fromJson(e)).toList();
      });
    } catch (e) {
      setState(() => _error = e.toString().contains('Error 404')
          ? 'Buyurtma topilmadi yoki ko‘rishga ruxsat yo‘q.'
          : e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _setStatus(String status) async {
    try {
      final token = context.read<AuthProvider>().token!;
      await ApiService.patch(
        'collections/orders/records/${widget.orderId}',
        {'status': status},
        token: token,
      );
      await _fetch();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Status: ${_statusUz(status)}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Status xatosi: $e')));
      }
    }
  }

  Future<void> _requestEdit() async => _setStatus('edit_requested');
  Future<void> _resendToWarehouse() async => _setStatus('created');

  Future<void> _deleteItem(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('O‘chirish?'),
        content: const Text('Mahsulotni buyurtmadan o‘chirmoqchimisiz?'),
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
      await ApiService.delete('collections/order_items/records/$id',
          token: token);
      await _fetch();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Xato: $e')));
      }
    }
  }

  Future<void> _printPackingSlip() async {
    try {
      final bytes = await PdfService.buildPackingSlip(
        order: _order!,
        items: _items,
        companyName: 'MaxDoors',
      );
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('PDF xatosi: $e')));
    }
  }

  /// Sarlavha ko‘rinishi (human_id > daily_seq+date > number+date > id)
  String _orderHuman(Order o) {
    final human = (_humanIdAny(o) ?? '').trim();
    if (human.isNotEmpty) return human;

    DateTime? created;
    if ((o.created ?? '').isNotEmpty) {
      created = DateTime.tryParse(o.created!)?.toLocal();
    }
    String datePart = '';
    if (created != null) {
      final dd = created.day.toString().padLeft(2, '0');
      final mm = created.month.toString().padLeft(2, '0');
      final yyyy = created.year.toString();
      datePart = '$dd.$mm.$yyyy';
    }

    int? seq;
    final rawSeq = _dailySeqAny(o);
    if (rawSeq is num) {
      seq = rawSeq.toInt();
    } else if (rawSeq is String) {
      seq = int.tryParse(rawSeq);
    }

    if (seq != null && seq > 0 && datePart.isNotEmpty) {
      return '${seq.toString().padLeft(3, '0')}-$datePart';
    }

    final number = (o.number ?? '').trim();
    if (number.isNotEmpty && datePart.isNotEmpty) {
      return '$number-$datePart';
    }

    return o.id;
  }

  @override
  Widget build(BuildContext context) {
    final titleText = (!_loading && _order != null)
        ? _orderHuman(_order!)
        : 'Buyurtma detali';

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
        actions: [
          if (!_loading && _order != null && _isWarehouse)
            IconButton(
              tooltip: 'Chop etish (PDF)',
              icon: const Icon(Icons.print),
              onPressed: _printPackingSlip,
            ),
          if (_canEditItems)
            IconButton(
              tooltip: 'Mahsulot qo‘shish',
              icon: const Icon(Icons.add),
              onPressed: _openAddItem,
            ),
        ],
      ),
      floatingActionButton: _canEditItems
          ? FloatingActionButton.extended(
              onPressed: _openAddItem,
              icon: const Icon(Icons.add),
              label: const Text('Mahsulot qo‘shish'),
            )
          : null,
      body: _loading
          ? const Loading(text: 'Yuklanmoqda...')
          : _error.isNotEmpty
              ? Center(child: Text('Xato: $_error'))
              : _order == null
                  ? const Center(child: Text('Topilmadi'))
                  : RefreshIndicator(
                      onRefresh: _fetch,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Header (status va meta)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Dealer: ${_order!.dealerLabel} • Region: ${_order!.regionLabel}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Manager: ${_order!.managerLabel} • Warehouse: ${_order!.warehouseLabel}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (_order!.note?.isNotEmpty == true)
                                      Text('Izoh: ${_order!.note}'),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: Colors.blueGrey.shade200),
                                ),
                                child: Text(
                                    'Status: ${_statusUz(_order!.status)}'),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Actions
                          if (_canRequestEdit)
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _requestEdit,
                                  icon: const Icon(Icons.edit_calendar),
                                  label: const Text('O‘zgartirish so‘rash'),
                                ),
                              ],
                            ),
                          if (_canResendToWarehouse)
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _resendToWarehouse,
                                  icon: const Icon(Icons.send),
                                  label: const Text('Omborga qayta yuborish'),
                                ),
                              ],
                            ),

                          const SizedBox(height: 8),
                          const Divider(),
                          const Text('Tovarlar',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),

                          if (_items.isEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Hozircha mahsulot qo‘shilmagan.'),
                                if (_canEditItems) ...[
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: _openAddItem,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Mahsulot qo‘shish'),
                                  ),
                                ],
                              ],
                            )
                          else
                            ..._items.map((it) {
                              final name = it.expandProductName ?? it.productId;
                              final qty = it.qty ?? 0;
                              final price = it.unitPriceUsd ?? 0;
                              final trailingDelete = _canEditItems
                                  ? IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () => _deleteItem(it.id),
                                    )
                                  : null;

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.inventory_2),
                                title: Text(name ?? '-'),
                                subtitle: Text(
                                    'Qty: $qty  •  \$${price.toStringAsFixed(2)}'),
                                trailing: trailingDelete,
                              );
                            }),

                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Subtotal",
                                  style:
                                      TextStyle(fontWeight: FontWeight.w500)),
                              Text('\$${_subtotalUsd.toStringAsFixed(2)}'),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Chegirma",
                                  style:
                                      TextStyle(fontWeight: FontWeight.w500)),
                              Text('- \$${_discountUsd.toStringAsFixed(2)}'),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Jami",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              Text('\$${_totalUsd.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 20),

                          if (_isWarehouse) ...[
                            ElevatedButton(
                              onPressed: () => _setStatus('packed'),
                              child: const Text('Yig‘ilgan (Packed)'),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => _setStatus('shipped'),
                              child: const Text('Jo‘natilgan (Shipped)'),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _printPackingSlip,
                              icon: const Icon(Icons.print),
                              label: const Text('Chop etish (PDF)'),
                            ),
                          ],
                        ],
                      ),
                    ),
    );
  }

  Future<void> _openAddItem() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OrderItemAddScreen(orderId: widget.orderId),
      ),
    );
    if (added == true && mounted) _fetch();
  }
}
