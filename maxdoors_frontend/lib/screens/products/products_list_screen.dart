import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xlsx;
import 'package:file_saver/file_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class ProductsListScreen extends StatefulWidget {
  const ProductsListScreen({super.key});

  @override
  State<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends State<ProductsListScreen> {
  bool _loading = true;
  String _error = '';
  List<Map<String, dynamic>> _items = [];
  int _page = 1;
  final int _perPage = 100;
  int _total = 0;

  // filters/search
  final _searchCtrl = TextEditingController();
  String _query = '';

  // expand for labels (category, unit, etc — sozlanadigan)
  final _expand = 'category';

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
          'collections/products/records?perPage=$_perPage&page=$_page&sort=-created');

      // expand labels
      sb.write('&expand=$_expand');

      if (_query.isNotEmpty) {
        final safe = _query.replaceAll("'", r"\'");
        final filter =
            "name~'$safe' || code~'$safe' || sku~'$safe' || description~'$safe'";
        sb.write('&filter=${Uri.encodeComponent(filter)}');
      }

      final res = await ApiService.get(sb.toString(), token: token);
      final items =
          List<Map<String, dynamic>>.from((res['items'] as List?) ?? const []);
      setState(() {
        _items = items;
        _total = (res['totalItems'] as num?)?.toInt() ?? items.length;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _refresh() => _fetch(resetPage: true);

  String _catName(Map<String, dynamic> row) {
    final exp = row['expand'];
    if (exp is Map && exp['category'] is Map) {
      return exp['category']['name']?.toString() ?? '-';
    }
    return row['category']?.toString() ?? '-';
  }

  String _fmtNum(num? n, {int frac = 2}) {
    if (n == null) return '';
    return n.toStringAsFixed(frac);
    // Agar intl ishlatsangiz: NumberFormat.decimalPattern().format(n)
  }

  // -------------------- EXPORT --------------------

  Future<void> _exportCsv() async {
    try {
      if (_items.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Ma’lumot yo‘q')));
        return;
      }

      // CSV header
      final rows = <List<dynamic>>[
        ['ID', 'Name', 'Code/SKU', 'Category', 'Price USD', 'Stock', 'Created']
      ];

      for (final p in _items) {
        rows.add([
          p['id'] ?? '',
          p['name'] ?? '',
          (p['code'] ?? p['sku'] ?? '').toString(),
          _catName(p),
          _fmtNum((p['price_usd'] ?? p['priceUsd']) is num
              ? (p['price_usd'] ?? p['priceUsd'])
              : num.tryParse(
                      (p['price_usd'] ?? p['priceUsd'] ?? '').toString()) ??
                  0),
          _fmtNum(
              (p['stock'] is num)
                  ? p['stock']
                  : num.tryParse('${p['stock']}') ?? 0,
              frac: 0),
          (p['created'] ?? '').toString(),
        ]);
      }

      final csv = const ListToCsvConverter().convert(rows);
      final bytes = Uint8List.fromList(utf8.encode(csv));

      final fileName =
          'products_${DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-')}.csv';

      await _saveBytes(bytes, fileName, MimeType.csv);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV eksport qilindi: $fileName')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('CSV xatosi: $e')));
    }
  }

  Future<void> _exportXlsx() async {
    try {
      if (_items.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Ma’lumot yo‘q')));
        return;
      }

      final excel = xlsx.Excel.createExcel();
      final sheet = excel['Products'];

      // header
      final header = [
        'ID',
        'Name',
        'Code/SKU',
        'Category',
        'Price USD',
        'Stock',
        'Created'
      ];
      sheet.appendRow(header.cast<xlsx.CellValue?>());

      for (final p in _items) {
        sheet.appendRow([
          p['id'] ?? '',
          p['name'] ?? '',
          (p['code'] ?? p['sku'] ?? '').toString(),
          _catName(p),
          (p['price_usd'] ?? p['priceUsd'])?.toString() ?? '',
          (p['stock'] ?? '').toString(),
          (p['created'] ?? '').toString(),
        ]);
      }

      final bytes = Uint8List.fromList(excel.encode()!);
      final fileName =
          'products_${DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-')}.xlsx';

      await _saveBytes(bytes, fileName, MimeType.microsoftExcel);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel eksport qilindi: $fileName')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Excel xatosi: $e')));
    }
  }

  /// Faylni saqlash: avval FileSaver, agar platforma/permission sababli
  /// ishlamasa, temporary papkaga yozib qo‘yamiz.
  Future<void> _saveBytes(Uint8List bytes, String name, MimeType mime) async {
    try {
      await FileSaver.instance.saveFile(
        name: name,
        bytes: bytes,
        mimeType: mime,
      );
    } catch (_) {
      // fallback
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/$name');
      await f.writeAsBytes(bytes);
    }
  }

  // -------------------- UI --------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mahsulotlar'),
        actions: [
          IconButton(
            tooltip: 'Yangilash',
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetch(resetPage: true),
          ),
          PopupMenuButton<String>(
            tooltip: 'Export',
            onSelected: (v) {
              if (v == 'csv') _exportCsv();
              if (v == 'xlsx') _exportXlsx();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, size: 18),
                    SizedBox(width: 8),
                    Text('Export CSV'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'xlsx',
                child: Row(
                  children: [
                    Icon(Icons.grid_on, size: 18),
                    SizedBox(width: 8),
                    Text('Export Excel (.xlsx)'),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.file_download),
          ),
        ],
      ),
      body: Column(
        children: [
          // search
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Qidirish (nom / code / sku / izoh)',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
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
                ? const Center(child: Text('Mahsulotlar topilmadi'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final it = _items[i];
                      final name = (it['name'] ?? '').toString();
                      final code = (it['code'] ?? it['sku'] ?? '').toString();
                      final cat = _catName(it);
                      final price = (it['price_usd'] ?? it['priceUsd']);
                      final stock = it['stock'];

                      return Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.blueGrey.withOpacity(0.2)),
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                              child: Icon(Icons.inventory_2)),
                          title: Text(
                            name.isEmpty ? '-' : name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (code.isNotEmpty) Text('Code/SKU: $code'),
                              Text('Kategoriya: $cat'),
                              Row(
                                children: [
                                  Text('Narx (USD): ${_fmtNum(_toNum(price))}'),
                                  const SizedBox(width: 12),
                                  Text(
                                      'Qoldiq: ${_fmtNum(_toNum(stock), frac: 0)}'),
                                ],
                              ),
                            ],
                          ),
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

  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? '') ?? 0;
  }
}
