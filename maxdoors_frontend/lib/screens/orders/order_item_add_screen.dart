import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/async_dropdown.dart';

class OrderItemAddScreen extends StatefulWidget {
  final String orderId;
  const OrderItemAddScreen({super.key, required this.orderId});

  @override
  State<OrderItemAddScreen> createState() => _OrderItemAddScreenState();
}

class _OrderItemAddScreenState extends State<OrderItemAddScreen> {
  String? _supplierId; // ixtiyoriy filter
  String? _categoryId; // ixtiyoriy filter
  String? _productId;

  // Agar sizda category field nomi boshqacha bo‘lsa (masalan: category_id),
  // shu yerda almashtiring:
  static const String categoryFieldName = 'category';

  final qtyCtrl = TextEditingController(text: '1');
  bool saving = false;

  Map<String, dynamic>? _selectedProduct; // narx/qoldiq ko‘rsatish

  Future<List<Map<String, String>>> _fetchSuppliers() async {
    final auth = context.read<AuthProvider>();
    final res = await ApiService.get(
      "collections/suppliers/records?perPage=200&sort=name",
      token: auth.token,
    );
    final items = List<Map<String, dynamic>>.from(res['items'] as List);
    return items
        .map((e) => {
              'id': e['id'] as String,
              'label': (e['name'] ?? e['id']).toString()
            })
        .toList();
  }

  // ✅ Kategoriyalar: ikki xil nomni sinab ko‘ramiz, bo‘lmasa jim qaytamiz ([])
  Future<List<Map<String, String>>> _fetchCategories() async {
    final auth = context.read<AuthProvider>();
    final tryEndpoints = <String>[
      "collections/product_categories/records?perPage=200&sort=name",
      "collections/categories/records?perPage=200&sort=name",
    ];

    for (final url in tryEndpoints) {
      try {
        final res = await ApiService.get(url, token: auth.token);
        final items = List<Map<String, dynamic>>.from(res['items'] as List);
        if (items.isNotEmpty) {
          return items
              .map((e) => {
                    'id': e['id'] as String,
                    'label': (e['name'] ?? e['id']).toString()
                  })
              .toList();
        }
      } catch (_) {
        // keyingi endpointni sinaymiz
      }
    }
    // Kategoriya kolleksiyasi bo‘lmasa ham UI ishlayversin
    return <Map<String, String>>[];
  }

  Future<List<Map<String, String>>> _fetchProducts() async {
    final auth = context.read<AuthProvider>();
    var url = "collections/products/records?perPage=200&sort=name";
    final filters = <String>[];
    if (_categoryId?.isNotEmpty == true)
      filters.add("$categoryFieldName='$_categoryId'");
    if (_supplierId?.isNotEmpty == true) filters.add("supplier='$_supplierId'");
    if (filters.isNotEmpty) url += "&filter=${filters.join(' && ')}";

    final res = await ApiService.get(url, token: auth.token);
    final items = List<Map<String, dynamic>>.from(res['items'] as List);
    return items
        .map((e) => {
              'id': e['id'] as String,
              'label': (e['name'] ?? e['id']).toString()
            })
        .toList();
  }

  Future<void> _loadSelectedProduct() async {
    if (_productId == null) {
      setState(() => _selectedProduct = null);
      return;
    }
    try {
      final auth = context.read<AuthProvider>();
      final res = await ApiService.get(
          "collections/products/records/$_productId",
          token: auth.token);
      setState(() => _selectedProduct = res);
    } catch (_) {
      setState(() => _selectedProduct = null);
    }
  }

  Future<void> _save() async {
    final qty = int.tryParse(qtyCtrl.text.trim());
    if (_productId == null || qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Mahsulot tanlang va to‘g‘ri miqdor kiriting")),
      );
      return;
    }

    setState(() => saving = true);
    try {
      final token = context.read<AuthProvider>().token!;

      final num? priceRaw =
          _selectedProduct?['sell_price_usd'] ?? _selectedProduct?['price_usd'];
      final double? unitPriceUsd =
          priceRaw == null ? null : (priceRaw as num).toDouble();

      final body = {
        "order": widget.orderId,
        "product": _productId,
        "qty": qty, // ✅ ESKI: "quantity" → YANGI: "qty"
        if (unitPriceUsd != null) "unit_price_usd": unitPriceUsd,
      };

      await ApiService.post("collections/order_items/records", body,
          token: token);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Xato: $e")));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stock =
        _selectedProduct?['stock_qty'] ?? _selectedProduct?['available_qty'];
    final price =
        _selectedProduct?['sell_price_usd'] ?? _selectedProduct?['price_usd'];
    final barcode =
        _selectedProduct?['barcode'] ?? _selectedProduct?['code128'];

    return Scaffold(
      appBar: AppBar(title: const Text("Mahsulot qo‘shish")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // Supplier — ixtiyoriy filter
            AsyncDropdown(
              label: "Supplier (ixtiyoriy filter)",
              value: _supplierId,
              fetchOptions: _fetchSuppliers,
              onChanged: (v) {
                setState(() {
                  _supplierId = v;
                  _productId = null;
                  _selectedProduct = null;
                });
              },
            ),
            const SizedBox(height: 8),
            // Category — mavjud bo‘lmasa jim qoladi
            AsyncDropdown(
              label: "Kategoriya (ixtiyoriy)",
              value: _categoryId,
              fetchOptions: _fetchCategories,
              onChanged: (v) {
                setState(() {
                  _categoryId = v;
                  _productId = null;
                  _selectedProduct = null;
                });
              },
            ),
            const SizedBox(height: 8),
            // Mahsulot — majburiy
            AsyncDropdown(
              label: "Mahsulot",
              value: _productId,
              fetchOptions: _fetchProducts,
              onChanged: (v) async {
                setState(() => _productId = v);
                await _loadSelectedProduct();
              },
            ),
            const SizedBox(height: 8),
            if (_selectedProduct != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Qoldiq (defektsiz): ${stock ?? '-'}"),
                  Text("Narx (USD): ${price ?? '-'}"),
                ],
              ),
              const SizedBox(height: 4),
              Text("Shtrix-kod: ${barcode ?? '-'}",
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Miqdor"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: saving ? null : _save,
              child: Text(saving ? "Kutilmoqda..." : "Qo‘shish"),
            ),
          ],
        ),
      ),
    );
  }
}
