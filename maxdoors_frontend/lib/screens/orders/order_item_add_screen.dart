import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class OrderItemAddScreen extends StatefulWidget {
  final String orderId;

  const OrderItemAddScreen({super.key, required this.orderId});

  @override
  State<OrderItemAddScreen> createState() => _OrderItemAddScreenState();
}

class _OrderItemAddScreenState extends State<OrderItemAddScreen> {
  // Filters
  final _searchCtrl = TextEditingController();
  String _q = '';
  String? _supplierId;
  String? _categoryId;

  // Data
  bool _loading = true;
  String _error = '';
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _categories = [];
  final List<Map<String, dynamic>> _products = [];

  // paging
  int _page = 1;
  bool _hasMore = true;
  bool _loadingMore = false;

  // add form (opens on tap)
  Map<String, dynamic>? _selectedProduct;
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = '';
      _products.clear();
      _page = 1;
      _hasMore = true;
    });
    try {
      final token = context.read<AuthProvider>().token!;
      // load filters
      final resSup = await ApiService.get(
        'collections/suppliers/records?perPage=200&sort=name',
        token: token,
      );
      final resCat = await ApiService.get(
        'collections/categories/records?perPage=200&sort=name',
        token: token,
      );
      _suppliers =
          List<Map<String, dynamic>>.from(resSup['items'] as List? ?? []);
      _categories =
          List<Map<String, dynamic>>.from(resCat['items'] as List? ?? []);
      await _loadProducts(reset: true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  String _buildFilter() {
    final filters = <String>[];
    if ((_q).isNotEmpty) {
      final safe = _q.replaceAll("'", r"\'");
      filters.add(
          "(name~'$safe' || code~'$safe' || sku~'$safe' || barcode~'$safe')");
    }
    if (_supplierId != null && _supplierId!.isNotEmpty) {
      filters.add("supplier='$_supplierId'");
    }
    if (_categoryId != null && _categoryId!.isNotEmpty) {
      filters.add("category='$_categoryId'");
    }
    return filters.isEmpty ? '' : Uri.encodeComponent(filters.join(' && '));
  }

  Future<void> _loadProducts({bool reset = false}) async {
    if (reset) {
      _products.clear();
      _page = 1;
      _hasMore = true;
    }
    if (!_hasMore || _loadingMore) return;

    setState(() => _loadingMore = true);
    try {
      final token = context.read<AuthProvider>().token!;
      final filter = _buildFilter();
      final filterPart = filter.isEmpty ? '' : '&filter=$filter';
      final url =
          'collections/products/records?perPage=50&page=$_page&sort=name&expand=supplier,category$filterPart';
      final res = await ApiService.get(url, token: token);
      final items =
          List<Map<String, dynamic>>.from(res['items'] as List? ?? []);
      _products.addAll(items);
      final total = (res['totalItems'] as num?)?.toInt() ?? _products.length;
      if (_products.length >= total || items.isEmpty) {
        _hasMore = false;
      } else {
        _page++;
      }
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Yuklash xatosi: $e')));
      }
      _hasMore = false;
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  String _expandName(Map<String, dynamic> row, String rel) {
    final exp = row['expand'];
    if (exp is Map && exp[rel] is Map && exp[rel]['name'] != null) {
      return exp[rel]['name'].toString();
    }
    return '-';
  }

  double _toD(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  void _pickProduct(Map<String, dynamic> p) {
    _selectedProduct = p;
    final sale = _toD(p['sale_price_usd'] ?? p['price_usd']);
    final cost = _toD(p['cost_price_usd']);
    final price = sale > 0 ? sale : (cost > 0 ? cost : 0.0);
    _priceCtrl.text = price.toStringAsFixed(2);
    _qtyCtrl.text = '1';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: max(MediaQuery.of(context).viewInsets.bottom, 16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p['name']?.toString() ?? p['id'].toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'OK: ${_toD(p['stock_ok']).toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                if (_toD(p['stock_defect']).abs() > 0.0001)
                  Text(
                    'DEF: ${_toD(p['stock_defect']).toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.redAccent, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Price (USD)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.check),
                label: const Text('Qo‘shish'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addItem() async {
    final p = _selectedProduct;
    if (p == null) return;
    final qty = double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ?? 0;
    final price = double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Qty 0 dan katta bo‘lishi kerak')));
      return;
    }
    try {
      final token = context.read<AuthProvider>().token!;
      await ApiService.post(
        'collections/order_items/records',
        {
          'order': widget.orderId,
          'product': p['id'],
          'qty': qty,
          'unit_price_usd': price,
        },
        token: token,
      );
      if (!mounted) return;
      Navigator.pop(context); // close sheet
      Navigator.pop(context, true); // return to order detail with success
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Qo‘shishda xato: $e')));
    }
  }

  Widget _productTile(Map<String, dynamic> p) {
    final name = (p['name'] ?? p['id']).toString();
    final supplier = _expandName(p, 'supplier');
    final category = _expandName(p, 'category');
    final barcode = (p['barcode'] ?? '').toString();
    final ok = _toD(p['stock_ok']);
    final defect = _toD(p['stock_defect']);
    final sale = _toD(p['sale_price_usd'] ?? p['price_usd']);
    return ListTile(
      onTap: () => _pickProduct(p),
      leading: const Icon(Icons.inventory_2),
      title: Row(
        children: [
          Expanded(child: Text(name)),
          const SizedBox(width: 6),
          // stock badges
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              border: Border.all(color: Colors.green.shade300),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('OK: ${ok.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          if (defect.abs() >= 0.0001) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.06),
                border: Border.all(color: Colors.red.shade300),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('DEF: ${defect.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
      subtitle: Text(
        'Brand: $supplier • Cat: $category • ${barcode.isEmpty ? "" : "Barcode: $barcode • "}\$${sale.toStringAsFixed(2)}',
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mahsulot tanlash')),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Qidirish (nom/kod/barcode)',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) {
                      setState(() => _q = _searchCtrl.text.trim());
                      _loadProducts(reset: true);
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    value: _supplierId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Brand (supplier)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Barchasi')),
                      ..._suppliers.map(
                        (s) => DropdownMenuItem<String>(
                          value: s['id'].toString(),
                          child: Text(s['name']?.toString() ?? s['id']),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _supplierId = v);
                      _loadProducts(reset: true);
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    value: _categoryId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Barchasi')),
                      ..._categories.map(
                        (c) => DropdownMenuItem<String>(
                          value: c['id'].toString(),
                          child: Text(c['name']?.toString() ?? c['id']),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _categoryId = v);
                      _loadProducts(reset: true);
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _q = _searchCtrl.text.trim());
                    _loadProducts(reset: true);
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
          const Divider(height: 1),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (sn) {
                if (sn.metrics.pixels + 200 >= sn.metrics.maxScrollExtent) {
                  _loadProducts();
                }
                return false;
              },
              child: _products.isEmpty && !_loading
                  ? const Center(child: Text('Mahsulot topilmadi'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      itemCount: _products.length + (_hasMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        if (i >= _products.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final p = _products[i];
                        return Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: _productTile(p),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
