import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/order.dart';
import '../../widgets/loading.dart';
import 'order_item_add_screen.dart';
import '../../services/pdf_service.dart';

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

  bool get _isManager {
    final r = context.read<AuthProvider>().role ?? '';
    return r == 'manager';
  }

  bool get _isWarehouse {
    final r = context.read<AuthProvider>().role ?? '';
    return r == 'warehouseman';
  }

  bool get _isAdminOrAcc {
    final r = context.read<AuthProvider>().role ?? '';
    return r == 'admin' || r == 'accountant';
  }

  bool get _canEditItems {
    if (_order == null) return false;
    final st = _order!.status ?? '';
    final canRole = _isManager || _isAdminOrAcc;
    return canRole && st == 'editable';
  }

  bool get _canRequestEdit {
    if (_order == null) return false;
    final st = _order!.status ?? '';
    // Manager created/packed/shipped holatlarda tahrir so'rashi mumkin
    return _isManager && (st == 'created' || st == 'packed' || st == 'shipped');
  }

  bool get _canResendToWarehouse {
    if (_order == null) return false;
    final st = _order!.status ?? '';
    // Manager yoki Admin/Accountant editable holatda created'ga qayta jo'natadi
    return (_isManager || _isAdminOrAcc) && st == 'editable';
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Status: $status')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Status xatosi: $e')));
      }
    }
  }

  Future<void> _requestEdit() async {
    // manager → edit_requested
    await _setStatus('edit_requested');
  }

  Future<void> _resendToWarehouse() async {
    // editable → created
    await _setStatus('created');
  }

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

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final role = context.read<AuthProvider>().role ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buyurtma detali'),
        actions: [
          if (!_loading && _order != null && _isWarehouse)
            IconButton(
              tooltip: 'Chop etish (PDF)',
              icon: const Icon(Icons.print),
              onPressed: _printPackingSlip,
            ),
        ],
      ),
      floatingActionButton: _canEditItems
          ? FloatingActionButton.extended(
              onPressed: () async {
                final added = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          OrderItemAddScreen(orderId: widget.orderId)),
                );
                if (added == true) {
                  if (mounted) _fetch();
                }
              },
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
                          // Sarlavha va status
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _order!.numberOrId,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: Colors.blueGrey.shade200),
                                ),
                                child: Text('Status: ${_order!.status ?? "-"}'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                              'Dealer: ${_order!.dealerLabel} • Region: ${_order!.regionLabel}'),
                          Text(
                              'Manager: ${_order!.managerLabel} • Warehouse: ${_order!.warehouseLabel}'),
                          if (_order!.note?.isNotEmpty == true)
                            Text('Izoh: ${_order!.note}'),
                          const SizedBox(height: 12),

                          // MANAGER ACTIONS
                          if (_canRequestEdit)
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _requestEdit,
                                  icon: const Icon(Icons.edit_calendar),
                                  label: const Text('Request edit'),
                                ),
                              ],
                            ),
                          if (_canResendToWarehouse)
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _resendToWarehouse,
                                  icon: const Icon(Icons.send),
                                  label: const Text('Re-send to warehouse'),
                                ),
                              ],
                            ),

                          const SizedBox(height: 8),
                          const Divider(),

                          const Text('Tovarlar',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),

                          if (_items.isEmpty)
                            const Text('Hozircha mahsulot qo‘shilmagan.')
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
                                title: Text(name!),
                                subtitle: Text(
                                    'Qty: $qty  •  \$${price.toStringAsFixed(2)}'),
                                trailing: trailingDelete,
                              );
                            }).toList(),

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

                          // WAREHOUSE ACTIONS
                          if (_isWarehouse) ...[
                            ElevatedButton(
                                onPressed: () => _setStatus('packed'),
                                child: const Text('Packed')),
                            const SizedBox(height: 8),
                            ElevatedButton(
                                onPressed: () => _setStatus('shipped'),
                                child: const Text('Shipped')),
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
}
