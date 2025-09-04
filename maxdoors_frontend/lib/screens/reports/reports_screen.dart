import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

/// Reports & Analytics (Orders + Payments + Products)
/// - KPI: revenue, payments, net-debt, orders count
/// - YANGI: Orders status KPI (created/edit_requested/editable/packed/shipped)
/// - Filters: date range, region, manager, dealer
/// - Charts:
///   1) Monthly Sales (USD) – Line
///   2) Monthly Payments (USD) – Bar
///   3) Top Dealers (USD) – Pie (drill-down qo‘shildi)
///   4) Top Products (USD) – Bar
///   5) Selected Product Trend (USD by month) – Line
///
/// Eslatma:
/// - PB’da agregatsiya yo‘qligi uchun ko‘p joyda totalItems asosida sanoq olinadi.
/// - UZS to‘lov: amount / fx_rate -> USD.

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _loading = true;
  String _error = '';

  // filters
  DateTime _from = DateTime(DateTime.now().year, 1, 1);
  DateTime _to =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  String? _regionId;
  String? _managerId;
  String? _dealerId;

  // debounce
  Timer? _debounce;
  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _bootstrap);
  }

  // dropdown options
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _managers = [];
  List<Map<String, dynamic>> _dealers = [];

  // raw data
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _payments = [];

  // computed (orders + payments)
  double _revenueUsd = 0;
  double _paymentsUsd = 0;
  int _ordersCount = 0;
  double get _netDebt => _revenueUsd - _paymentsUsd;

  // MoM/YoY (Savdo)
  double? _momPct;
  double? _yoyPct;

  // sales/payments by month
  Map<String, double> _salesByMonth = {}; // "YYYY-MM" -> USD
  Map<String, double> _paymentsByMonth = {}; // "YYYY-MM" -> USD

  // dealers
  List<_DealerSlice> _topDealers = [];

  // ----------- PRODUCTS -----------
  final Map<String, double> _productUsdTotal = {}; // productId -> usd
  final Map<String, double> _productQtyTotal = {}; // productId -> qty
  final Map<String, String> _productNames = {}; // productId -> name (expand)
  final Map<String, Map<String, double>> _productUsdByMonth =
      {}; // productId -> { "YYYY-MM" : usd }
  String? _selectedProductId; // trend uchun

  // ----------- ORDERS STATUS KPI -----------
  static const List<String> _orderStatuses = [
    'created',
    'edit_requested',
    'editable',
    'packed',
    'shipped',
  ];

  static const Map<String, String> _statusUz = {
    'created': 'Yangi',
    'edit_requested': "O'zgartirish so‘ralgan",
    'editable': "O'zgartirish mumkin",
    'packed': 'Yig‘ilgan',
    'shipped': 'Jo‘natilgan',
  };

  Map<String, int> _orderStatusCounts = {}; // status -> count
  int _orderStatusTotal = 0;

  final _fmtMonth = DateFormat('yyyy-MM');
  final _fmtHuman = DateFormat('dd.MM.yyyy');
  final _fmtMoney = NumberFormat.compactCurrency(symbol: '\$');

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final token = context.read<AuthProvider>().token!;
      await _loadDropdowns(token);
      await _loadData(token);
      await _compute(token);
      await _loadOrderStatusKpi(token); // <-- status KPI
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDropdowns(String token) async {
    // Regions
    final r = await ApiService.get(
      'collections/regions/records?perPage=200&sort=name',
      token: token,
    );
    _regions = List<Map<String, dynamic>>.from(r['items'] as List);

    // Managers (users.role=manager)
    final m = await ApiService.get(
      "collections/users/records?perPage=200&filter=${Uri.encodeComponent("role='manager'")}&sort=name",
      token: token,
    );
    _managers = List<Map<String, dynamic>>.from(m['items'] as List);

    // Dealers
    final d = await ApiService.get(
      'collections/dealers/records?perPage=500&sort=name',
      token: token,
    );
    _dealers = List<Map<String, dynamic>>.from(d['items'] as List);
  }

  // --- Foydalaniladigan filterlarni (orders/payments uchun) bir joyda yig‘amiz
  List<String> _orderFilterParts() {
    final parts = <String>[];
    final fromIso = _from.toUtc().toIso8601String();
    final toIso =
        _to.add(const Duration(days: 1)).toUtc().toIso8601String(); // end-excl
    parts.add("created>='$fromIso'");
    parts.add("created<'$toIso'");
    if (_regionId != null && _regionId!.isNotEmpty) {
      parts.add("region='$_regionId'");
    }
    if (_managerId != null && _managerId!.isNotEmpty) {
      parts.add("manager='$_managerId'");
    }
    if (_dealerId != null && _dealerId!.isNotEmpty) {
      parts.add("dealer='$_dealerId'");
    }
    return parts;
  }

  List<String> _paymentFilterParts() {
    final parts = <String>[];
    final fromIso = _from.toUtc().toIso8601String();
    final toIso =
        _to.add(const Duration(days: 1)).toUtc().toIso8601String(); // end-excl
    parts.add("created>='$fromIso'");
    parts.add("created<'$toIso'");
    if (_regionId != null && _regionId!.isNotEmpty) {
      parts.add("region='$_regionId'");
    }
    if (_dealerId != null && _dealerId!.isNotEmpty) {
      parts.add("dealer='$_dealerId'");
    }
    return parts;
  }

  Future<void> _loadData(String token) async {
    final orderFilterStr =
        Uri.encodeComponent(_orderFilterParts().join(' && '));
    final payFilterStr =
        Uri.encodeComponent(_paymentFilterParts().join(' && '));

    _orders = await _fetchAll(
      path: 'collections/orders/records',
      token: token,
      perPage: 200,
      extra: '&filter=$orderFilterStr&expand=dealer,region,manager',
    );

    _payments = await _fetchAll(
      path: 'collections/payments/records',
      token: token,
      perPage: 200,
      extra: '&filter=$payFilterStr&expand=dealer,region',
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAll({
    required String path,
    required String token,
    required int perPage,
    String extra = '',
  }) async {
    int page = 1;
    final out = <Map<String, dynamic>>[];
    while (true) {
      final url = '$path?perPage=$perPage&page=$page$extra';
      final res = await ApiService.get(url, token: token);
      final items =
          List<Map<String, dynamic>>.from((res['items'] as List?) ?? const []);
      out.addAll(items);
      final total = (res['totalItems'] as num?)?.toInt() ?? out.length;
      if (out.length >= total || items.isEmpty) break;
      page++;
      if (page > 50) break; // guard
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> _fetchOrderItems(
      String orderId, String token) async {
    return await _fetchAll(
      path: 'collections/order_items/records',
      token: token,
      perPage: 200,
      extra:
          "&filter=${Uri.encodeComponent("order='$orderId'")}&expand=product",
    );
  }

  Future<void> _compute(String token) async {
    // reset
    _revenueUsd = 0;
    _paymentsUsd = 0;
    _ordersCount = _orders.length;
    _salesByMonth = {};
    _paymentsByMonth = {};
    _topDealers = [];
    _productUsdTotal.clear();
    _productQtyTotal.clear();
    _productNames.clear();
    _productUsdByMonth.clear();
    _momPct = null;
    _yoyPct = null;

    // ---------- Orders (with items) ----------
    double revenue = 0.0;
    final byDealer = <String, double>{};

    for (final o in _orders) {
      final created = DateTime.tryParse(o['created']?.toString() ?? '') ??
          DateTime.now().toUtc();
      final bucket = _fmtMonth.format(created.toLocal());

      // itemlarni olib kelamiz
      final items = await _fetchOrderItems(o['id'].toString(), token);

      // subtotal va discount
      double subtotal = 0.0;
      for (final it in items) {
        final qty = (it['qty'] is num)
            ? (it['qty'] as num).toDouble()
            : double.tryParse(it['qty']?.toString() ?? '0') ?? 0.0;
        final priceRaw =
            (it['unit_price_usd'] ?? it['unitPriceUsd'] ?? it['price_usd']);
        final price = (priceRaw is num)
            ? priceRaw.toDouble()
            : double.tryParse(priceRaw?.toString() ?? '0') ?? 0.0;
        final rowUsd = qty * price;
        subtotal += rowUsd;

        // --- PRODUCTS AGGREGATION ---
        final productId = it['product']?.toString() ?? '';
        if (productId.isNotEmpty) {
          final exp = it['expand'];
          if (exp is Map && exp['product'] is Map) {
            final nm = exp['product']['name']?.toString();
            if (nm != null && nm.isNotEmpty) {
              _productNames[productId] = nm;
            }
          }
          _productUsdTotal[productId] =
              (_productUsdTotal[productId] ?? 0) + rowUsd;
          _productQtyTotal[productId] =
              (_productQtyTotal[productId] ?? 0) + qty;
          // monthly
          _productUsdByMonth.putIfAbsent(productId, () => {});
          final m = _productUsdByMonth[productId]!;
          m[bucket] = (m[bucket] ?? 0) + rowUsd;
        }
      }

      // discount
      final discType =
          (o['discount_type'] ?? o['discountType'])?.toString() ?? 'none';
      final discValRaw = (o['discount_value'] ?? o['discountValue']);
      final discVal = (discValRaw is num)
          ? discValRaw.toDouble()
          : double.tryParse(discValRaw?.toString() ?? '0') ?? 0.0;
      double discount = 0.0;
      if (discType == 'percent') discount = subtotal * (discVal / 100.0);
      if (discType == 'amount') discount = discVal;

      final orderTotal = (subtotal - discount).clamp(0, double.infinity);
      revenue += orderTotal;

      // monthly sales
      _salesByMonth[bucket] = (_salesByMonth[bucket] ?? 0) + orderTotal;

      // by dealer
      final dealerId = o['dealer']?.toString() ?? '';
      if (dealerId.isNotEmpty) {
        byDealer[dealerId] = (byDealer[dealerId] ?? 0) + orderTotal;
      }

      if (mounted) setState(() {}); // progressive repaint
    }

    // ---------- Payments ----------
    double pays = 0.0;
    for (final p in _payments) {
      final curr = (p['currency']?.toString() ?? 'USD').toUpperCase();
      final amountRaw = p['amount'];
      final fxRaw = p['fx_rate'];
      final amount = (amountRaw is num)
          ? amountRaw.toDouble()
          : double.tryParse(amountRaw?.toString() ?? '0') ?? 0.0;
      final fx = (fxRaw is num)
          ? fxRaw.toDouble()
          : double.tryParse(fxRaw?.toString() ?? '0') ?? 0.0;
      final usd = curr == 'UZS' ? (fx > 0 ? amount / fx : 0.0) : amount;

      pays += usd;

      final created = DateTime.tryParse(p['created']?.toString() ?? '') ??
          DateTime.now().toUtc();
      final bucket = _fmtMonth.format(created.toLocal());
      _paymentsByMonth[bucket] = (_paymentsByMonth[bucket] ?? 0) + usd;

      if (mounted) setState(() {});
    }

    // ---------- Top dealers ----------
    final slices = <_DealerSlice>[];
    for (final entry in byDealer.entries) {
      final dealerId = entry.key;
      // label from expand if possible
      String label = dealerId;
      final anyOrder = _orders.firstWhere(
        (o) => o['dealer']?.toString() == dealerId,
        orElse: () => {},
      );
      final exp = anyOrder is Map ? anyOrder['expand'] : null;
      if (exp is Map && exp['dealer'] is Map) {
        label = (exp['dealer']['name']?.toString() ?? dealerId);
      }
      slices.add(_DealerSlice(id: dealerId, label: label, usd: entry.value));
    }
    slices.sort((a, b) => b.usd.compareTo(a.usd));
    _topDealers = slices.take(8).toList();

    // ---------- Top products (select default) ----------
    if (_productUsdTotal.isNotEmpty) {
      final top = _productUsdTotal.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      _selectedProductId ??= top.first.key;
    }

    // ---------- KPI set + MoM/YoY ----------
    _computeMoMYoY();

    setState(() {
      _revenueUsd = revenue;
      _paymentsUsd = pays;
    });
  }

  void _computeMoMYoY() {
    // Current month according to _to
    final nowYm = '${_to.year}-${_to.month.toString().padLeft(2, '0')}';
    // Prev month
    final prevDate = DateTime(_to.year, _to.month - 1, 1);
    final prevYm =
        '${prevDate.year}-${prevDate.month.toString().padLeft(2, '0')}';
    // YoY month
    final yoyDate = DateTime(_to.year - 1, _to.month, 1);
    final yoyYm = '${yoyDate.year}-${yoyDate.month.toString().padLeft(2, '0')}';

    final curr = _salesByMonth[nowYm];
    final prev = _salesByMonth[prevYm];
    final lastY = _salesByMonth[yoyYm];

    double? mom, yoy;
    if (curr != null && prev != null && prev > 0) {
      mom = ((curr / prev) - 1.0) * 100.0;
    }
    if (curr != null && lastY != null && lastY > 0) {
      yoy = ((curr / lastY) - 1.0) * 100.0;
    }
    _momPct = mom;
    _yoyPct = yoy;
  }

  // ===================== ORDERS STATUS KPI (totalItems orqali) =====================

  Future<int> _countOrders(String token, {String? status}) async {
    final parts = _orderFilterParts();
    if (status != null && status.isNotEmpty) {
      parts.add("status='$status'");
    }
    final filterStr = parts.isEmpty
        ? ''
        : '&filter=${Uri.encodeComponent(parts.join(' && '))}';
    final url =
        'collections/orders/records?page=1&perPage=1&fields=id$filterStr';
    final res = await ApiService.get(url, token: token);
    return (res['totalItems'] as num?)?.toInt() ?? 0;
  }

  Future<void> _loadOrderStatusKpi(String token) async {
    final total = await _countOrders(token);
    final map = <String, int>{};
    for (final s in _orderStatuses) {
      map[s] = await _countOrders(token, status: s);
    }
    setState(() {
      _orderStatusCounts = map;
      _orderStatusTotal = total;
    });
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'created':
        return Colors.blue.shade500;
      case 'edit_requested':
        return Colors.orange.shade700;
      case 'editable':
        return Colors.teal.shade600;
      case 'packed':
        return Colors.deepPurple.shade500;
      case 'shipped':
        return Colors.green.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  // Stable color per ID
  Color _colorForId(String id) {
    final h = id.hashCode & 0x00FFFFFF;
    return Color(0xFF000000 | h);
  }

  Widget _ordersStatusKpiCard() {
    final total = _orderStatusTotal == 0 ? 1 : _orderStatusTotal;
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stacked_bar_chart_outlined),
              const SizedBox(width: 8),
              const Text('Buyurtmalar — statuslar bo‘yicha',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('Jami: $_orderStatusTotal ta',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.primary)),
            ],
          ),
          const SizedBox(height: 12),
          ..._orderStatuses.map((s) {
            final count = _orderStatusCounts[s] ?? 0;
            final pct = count / total;
            final uz = _statusUz[s] ?? s;
            final color = _statusColor(s);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withOpacity(0.35)),
                        ),
                        child: Text(
                          uz,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text('$count ta  •  ${(pct * 100).toStringAsFixed(1)}%'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0, 1),
                      minHeight: 8,
                      color: color,
                      backgroundColor: color.withOpacity(0.08),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // =========================== UI ===========================

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2022, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _from,
    );
    if (d != null) {
      setState(() => _from = d);
      _scheduleReload();
    }
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2022, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _to,
    );
    if (d != null) {
      setState(() => _to = d);
      _scheduleReload();
    }
  }

  List<String> _monthsUnion() {
    final keys = <String>{};
    keys.addAll(_salesByMonth.keys);
    keys.addAll(_paymentsByMonth.keys);
    // products uchun ham qo‘shamiz (trendda bo‘lsin):
    if (_selectedProductId != null) {
      keys.addAll((_productUsdByMonth[_selectedProductId!] ?? {}).keys);
    }
    final out = keys.toList()..sort();
    return out;
  }

  // ------- Mahsulotlar dropdown itemlari helperi -------
  List<DropdownMenuItem<String>> _buildProductDropdownItems() {
    final entries = _productUsdTotal.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.take(50).map((e) {
      final id = e.key;
      final name = _productNames[id] ?? id;
      return DropdownMenuItem<String>(
        value: id,
        child: Text(name, overflow: TextOverflow.ellipsis),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistika & Analitika'),
        actions: [
          IconButton(onPressed: _bootstrap, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          // FILTERS
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickFrom,
                  icon: const Icon(Icons.date_range),
                  label: Text('dan: ${_fmtHuman.format(_from)}'),
                ),
                OutlinedButton.icon(
                  onPressed: _pickTo,
                  icon: const Icon(Icons.date_range),
                  label: Text('gacha: ${_fmtHuman.format(_to)}'),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String?>(
                    value: _regionId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Region',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('Barchasi')),
                      ..._regions.map((r) => DropdownMenuItem<String?>(
                            value: r['id'].toString(),
                            child: Text(r['name']?.toString() ?? r['id']),
                          )),
                    ],
                    onChanged: (v) {
                      setState(() => _regionId = v);
                      _scheduleReload();
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String?>(
                    value: _managerId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Menejer',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('Barchasi')),
                      ..._managers.map((m) => DropdownMenuItem<String?>(
                            value: m['id'].toString(),
                            child: Text(
                              m['name']?.toString() ??
                                  m['email']?.toString() ??
                                  m['id'],
                            ),
                          )),
                    ],
                    onChanged: (v) {
                      setState(() => _managerId = v);
                      _scheduleReload();
                    },
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<String?>(
                    value: _dealerId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Diller',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('Barchasi')),
                      ..._dealers.map((d) => DropdownMenuItem<String?>(
                            value: d['id'].toString(),
                            child: Text(d['name']?.toString() ?? d['id']),
                          )),
                    ],
                    onChanged: (v) {
                      setState(() => _dealerId = v);
                      _scheduleReload(); // debounce bilan qayta yuklash
                    },
                  ),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // KPI row (money + count)
                  Row(
                    children: [
                      _kpiCard(context,
                          title: 'Savdo (USD)',
                          value: _revenueUsd,
                          icon: Icons.attach_money,
                          color: Colors.indigo,
                          mom: _momPct,
                          yoy: _yoyPct),
                      const SizedBox(width: 12),
                      _kpiCard(context,
                          title: 'To‘lov (USD)',
                          value: _paymentsUsd,
                          icon: Icons.payments,
                          color: Colors.teal),
                      const SizedBox(width: 12),
                      _kpiCard(context,
                          title: 'Qarzdorlik (USD)',
                          value: _netDebt,
                          icon: Icons.account_balance_wallet,
                          color: _netDebt >= 0 ? Colors.red : Colors.green),
                      const SizedBox(width: 12),
                      _kpiCard(context,
                          title: 'Buyurtmalar',
                          value: _ordersCount.toDouble(),
                          icon: Icons.receipt_long,
                          color: Colors.blueGrey,
                          isInt: true),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // YANGI: Orders status KPI (progress + count)
                  _ordersStatusKpiCard(),

                  const SizedBox(height: 12),

                  // Sales & Payments charts
                  LayoutBuilder(
                    builder: (ctx, c) {
                      final isWide = c.maxWidth > 1000;
                      final a = _card(chartMonthlySales());
                      final b = _card(chartMonthlyPayments());
                      return isWide
                          ? Row(children: [
                              Expanded(child: a),
                              const SizedBox(width: 12),
                              Expanded(child: b)
                            ])
                          : Column(
                              children: [a, const SizedBox(height: 12), b]);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Top dealers (with quick dealer filter on header + drill-down)
                  _card(chartTopDealers()),
                  const SizedBox(height: 12),

                  // Top products + product trend
                  LayoutBuilder(
                    builder: (ctx, c) {
                      final isWide = c.maxWidth > 1000;
                      final a = _card(chartTopProducts());
                      final b = _card(chartProductTrend());
                      return isWide
                          ? Row(children: [
                              Expanded(child: a),
                              const SizedBox(width: 12),
                              Expanded(child: b)
                            ])
                          : Column(
                              children: [a, const SizedBox(height: 12), b]);
                    },
                  ),

                  const SizedBox(height: 12),
                  _card(topProductsTable()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------- Widgets -----------------------------------

  Widget _kpiCard(BuildContext context,
      {required String title,
      required double value,
      required IconData icon,
      required Color color,
      bool isInt = false,
      double? mom,
      double? yoy}) {
    final txt = isInt ? value.toStringAsFixed(0) : _fmtMoney.format(value);

    Widget badge(String label, double? pct) {
      if (pct == null) return const SizedBox.shrink();
      final up = pct >= 0;
      final bg = up ? Colors.green : Colors.red;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg.withOpacity(.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bg.withOpacity(.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(up ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14, color: bg),
            const SizedBox(width: 2),
            Text('${pct.toStringAsFixed(1)}%',
                style: TextStyle(color: bg, fontWeight: FontWeight.w700)),
            Text(' $label', style: TextStyle(color: bg)),
          ],
        ),
      );
    }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(txt,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              badge('MoM', mom),
              const SizedBox(width: 6),
              badge('YoY', yoy),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _card(Widget child) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: child,
    );
  }

  // ----------------------------- Charts ------------------------------------

  // 1) Oylik savdo (Line)
  Widget chartMonthlySales() {
    final months = _monthsUnion();
    final spots = <FlSpot>[];
    for (var i = 0; i < months.length; i++) {
      final k = months[i];
      final v = _salesByMonth[k] ?? 0;
      spots.add(FlSpot(i.toDouble(), v));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Oylik savdo (USD)',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SizedBox(
          height: 280,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: true),
              borderData: FlBorderData(show: true),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 52)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (v, meta) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= months.length) {
                        return const SizedBox();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(months[idx],
                            style: const TextStyle(fontSize: 10)),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  dotData: FlDotData(show: false),
                  barWidth: 3,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 2) Oylik to‘lov (Bar)
  Widget chartMonthlyPayments() {
    final months = _monthsUnion();
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < months.length; i++) {
      final k = months[i];
      final v = _paymentsByMonth[k] ?? 0;
      groups.add(BarChartGroupData(x: i, barRods: [BarChartRodData(toY: v)]));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Oylik to‘lovlar (USD)',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SizedBox(
          height: 280,
          child: BarChart(
            BarChartData(
              gridData: FlGridData(show: true),
              borderData: FlBorderData(show: true),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 52)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (v, meta) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= months.length) {
                        return const SizedBox();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(months[idx],
                            style: const TextStyle(fontSize: 10)),
                      );
                    },
                  ),
                ),
              ),
              barGroups: groups,
            ),
          ),
        ),
      ],
    );
  }

  // 3) Top dillerlar (Pie) + quick “Diller” filtri + DRILL-DOWN (tap)
  Widget chartTopDealers() {
    final data = _topDealers;
    final hasData = data.isNotEmpty;

    // Dropdown elementlari (Barchasi + dillerlar)
    final dealerItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(value: null, child: Text('Barchasi')),
      ..._dealers.map((d) => DropdownMenuItem<String?>(
            value: d['id'].toString(),
            child: Text(d['name']?.toString() ?? d['id']),
          )),
    ];

    Widget pie() {
      if (!hasData) {
        return const ListTile(
          title: Text('Top dillerlar'),
          subtitle: Text('Ma’lumot yetarli emas'),
        );
      }
      final sum = data.fold<double>(0, (p, e) => p + e.usd);
      final sections = <PieChartSectionData>[];
      for (var i = 0; i < data.length; i++) {
        final d = data[i];
        final pct = sum > 0 ? (d.usd / sum * 100) : 0;
        sections.add(
          PieChartSectionData(
            value: d.usd,
            color: _colorForId(d.id),
            title: '${pct.toStringAsFixed(0)}%',
            titleStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
            radius: 60 + min(40, (d.usd / (sum == 0 ? 1 : sum)) * 40),
            badgeWidget: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(
                d.label,
                style: const TextStyle(fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            badgePositionPercentageOffset: 1.25,
          ),
        );
      }
      return SizedBox(
        height: 320,
        child: PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 32,
            sections: sections,
            pieTouchData: PieTouchData(
              enabled: true,
              touchCallback: (evt, resp) {
                if (resp == null || resp.touchedSection == null) return;
                final idx = resp.touchedSection!.touchedSectionIndex;
                if (idx < 0 || idx >= data.length) return;
                final tapped = data[idx].id;
                setState(() {
                  // toggle: shu diller bo‘yicha filtrlash / tozalash
                  _dealerId = (_dealerId == tapped) ? null : tapped;
                });
                _scheduleReload();
              },
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Top dillerlar (USD)',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String?>(
                value: _dealerId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Diller',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: dealerItems,
                onChanged: (v) {
                  setState(() => _dealerId = v);
                  _scheduleReload();
                },
              ),
            ),
            const SizedBox(width: 8),
            if (_dealerId != null)
              IconButton(
                tooltip: 'Filterni tozalash',
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() => _dealerId = null);
                  _scheduleReload();
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        pie(),
      ],
    );
  }

  // 4) Top mahsulotlar (Bar)
  Widget chartTopProducts() {
    // USD bo‘yicha TOP-10
    final entries = _productUsdTotal.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(10).toList();
    if (top.isEmpty) {
      return const ListTile(
        title: Text('Top mahsulotlar'),
        subtitle: Text('Ma’lumot topilmadi'),
      );
    }

    final groups = <BarChartGroupData>[];
    for (var i = 0; i < top.length; i++) {
      final id = top[i].key;
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: top[i].value,
              color: _colorForId(id),
            )
          ],
          showingTooltipIndicators: const [0],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Top mahsulotlar (USD)',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SizedBox(
          height: 320,
          child: BarChart(
            BarChartData(
              gridData: FlGridData(show: true),
              borderData: FlBorderData(show: true),
              barGroups: groups,
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 52),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (v, meta) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= top.length) {
                        return const SizedBox();
                      }
                      final id = top[idx].key;
                      final nm = _productNames[id] ?? id;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: SizedBox(
                          width: 72,
                          child: Text(
                            nm,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 5) Tanlangan mahsulot trendi (Line)
  Widget chartProductTrend() {
    final pid = _selectedProductId;
    final months = _monthsUnion();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Mahsulot dinamikasi',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            SizedBox(
              width: 320,
              child: DropdownButtonFormField<String>(
                value: _selectedProductId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Mahsulot tanlang',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _buildProductDropdownItems(),
                onChanged: (v) => setState(() => _selectedProductId = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 280,
          child: pid == null
              ? const Center(child: Text('Mahsulot tanlang'))
              : LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true),
                    borderData: FlBorderData(show: true),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: true, reservedSize: 52),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          getTitlesWidget: (v, meta) {
                            final idx = v.toInt();
                            if (idx < 0 || idx >= months.length) {
                              return const SizedBox();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                months[idx],
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(months.length, (i) {
                          final k = months[i];
                          final v = _productUsdByMonth[pid]?[k] ?? 0;
                          return FlSpot(i.toDouble(), v);
                        }),
                        isCurved: true,
                        dotData: FlDotData(show: false),
                        barWidth: 3,
                        color: _colorForId(pid),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  // Jadval: TOP-20 mahsulotlar (USD, qty)
  Widget topProductsTable() {
    final rows = _productUsdTotal.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = rows.take(20).toList();

    if (top.isEmpty) {
      return const ListTile(
        title: Text('Mahsulotlar jadvali'),
        subtitle: Text('Hozircha ma’lumot yo‘q'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Top mahsulotlar — jadval',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        DataTable(
          columns: const [
            DataColumn(label: Text('#')),
            DataColumn(label: Text('Mahsulot')),
            DataColumn(label: Text('USD')),
            DataColumn(label: Text('Qty')),
          ],
          rows: List.generate(top.length, (i) {
            final id = top[i].key;
            final name = _productNames[id] ?? id;
            final usd = top[i].value;
            final qty = _productQtyTotal[id] ?? 0;
            return DataRow(cells: [
              DataCell(Text('${i + 1}')),
              DataCell(Text(name, overflow: TextOverflow.ellipsis)),
              DataCell(Text(_fmtMoney.format(usd))),
              DataCell(Text(qty.toStringAsFixed(2))),
            ]);
          }),
        ),
      ],
    );
  }
}

class _DealerSlice {
  final String id;
  final String label;
  final double usd;
  _DealerSlice({required this.id, required this.label, required this.usd});
}
