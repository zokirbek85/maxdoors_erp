import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xlsx;
import 'package:file_saver/file_saver.dart';
import 'package:path_provider/path_provider.dart';

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

  // expand for labels
  final _expand = 'category,supplier';

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
        'collections/products/records?perPage=$_perPage&page=$_page&sort=-created',
      );
      sb.write('&expand=$_expand');

      if (_query.isNotEmpty) {
        final safe = _query.replaceAll("'", r"\'");
        final filter =
            "name~'$safe' || barcode~'$safe' || size~'$safe' || color~'$safe'";
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

  Future<List<Map<String, dynamic>>> _fetchAll() async {
    final token = context.read<AuthProvider>().token!;
    final all = <Map<String, dynamic>>[];
    var page = 1;
    while (true) {
      final sb = StringBuffer(
        'collections/products/records?perPage=200&page=$page&sort=-created&expand=$_expand',
      );
      if (_query.isNotEmpty) {
        final safe = _query.replaceAll("'", r"\'");
        final filter =
            "name~'$safe' || barcode~'$safe' || size~'$safe' || color~'$safe'";
        sb.write('&filter=${Uri.encodeComponent(filter)}');
      }
      final res = await ApiService.get(sb.toString(), token: token);
      final items = List<Map<String, dynamic>>.from(res['items'] as List);
      all.addAll(items);
      final total = (res['totalItems'] as num?)?.toInt() ?? all.length;
      if (all.length >= total || items.isEmpty) break;
      page++;
    }
    return all;
  }

  Future<void> _refresh() => _fetch(resetPage: true);

  String _catName(Map<String, dynamic> row) {
    final exp = row['expand'];
    if (exp is Map && exp['category'] is Map) {
      return exp['category']['name']?.toString() ?? '-';
    }
    return row['category']?.toString() ?? '-';
  }

  String _supName(Map<String, dynamic> row) {
    final exp = row['expand'];
    if (exp is Map && exp['supplier'] is Map) {
      return exp['supplier']['name']?.toString() ?? '-';
    }
    return row['supplier']?.toString() ?? '-';
  }

  String _fmtNum(num? n, {int frac = 2}) {
    if (n == null) return '';
    return n.toStringAsFixed(frac);
  }

  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? '') ?? 0;
  }

  // -------------------- EXPORT (CSV) --------------------

  Future<void> _exportCsv() async {
    try {
      final data = _items.isEmpty ? await _fetchAll() : _items;

      if (data.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Ma’lumot yo‘q')));
        return;
      }

      // CSV header (soddaroq ko‘rinish)
      final rows = <List<dynamic>>[
        [
          'supplier',
          'category',
          'name',
          'barcode',
          'type',
          'size',
          'color',
          'qty_ok',
          'qty_defect',
          'cost_price_usd',
          'sale_price_usd',
          'amount_usd',
          'is_active',
          'created',
        ]
      ];

      for (final p in data) {
        rows.add([
          _supName(p),
          _catName(p),
          p['name'] ?? '',
          p['barcode'] ?? '',
          p['type'] ?? '',
          p['size'] ?? '',
          p['color'] ?? '',
          _fmtNum(_toNum(p['stock_ok']), frac: 2),
          _fmtNum(_toNum(p['stock_defect']), frac: 2),
          _fmtNum(_toNum(p['cost_price_usd']), frac: 2),
          _fmtNum(_toNum(p['price_usd']), frac: 2), // sale_price_usd
          _fmtNum(_toNum(p['avg_cost_usd']),
              frac: 2), // amount_usd (qarang izoh)
          (p['is_active'] == true) ? 1 : 0,
          (p['created'] ?? '').toString(),
        ]);
      }

      final csv = const ListToCsvConverter().convert(rows);
      final bytes = Uint8List.fromList(utf8.encode(csv));

      final fileName =
          'products_${DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-')}.csv';

      await _saveBytes(bytes, fileName, MimeType.csv);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV eksport qilindi: $fileName')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('CSV xatosi: $e')));
    }
  }

  // -------------------- EXPORT (XLSX, to‘liq) --------------------

  Future<void> _exportXlsxFull() async {
    try {
      final data = await _fetchAll();
      if (data.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Ma’lumot yo‘q')));
        return;
      }

      final excel = xlsx.Excel.createExcel();
      final sheet = excel['Products'];

      // Talab qilingan sarlavha
      final header = <xlsx.CellValue?>[
        xlsx.TextCellValue('supplier'),
        xlsx.TextCellValue('category'),
        xlsx.TextCellValue('name'),
        xlsx.TextCellValue('barcode'),
        xlsx.TextCellValue('type'),
        xlsx.TextCellValue('size'),
        xlsx.TextCellValue('color'),
        xlsx.TextCellValue('qty_ok'),
        xlsx.TextCellValue('qty_defect'),
        xlsx.TextCellValue('cost_price_usd'),
        xlsx.TextCellValue('sale_price_usd'),
        xlsx.TextCellValue('amount_usd'),
        xlsx.TextCellValue('is_active'),
        xlsx.TextCellValue('created'),
      ];
      sheet.appendRow(header);

      for (final p in data) {
        sheet.appendRow(<xlsx.CellValue?>[
          xlsx.TextCellValue(_supName(p)),
          xlsx.TextCellValue(_catName(p)),
          xlsx.TextCellValue((p['name'] ?? '').toString()),
          xlsx.TextCellValue((p['barcode'] ?? '').toString()),
          xlsx.TextCellValue((p['type'] ?? '').toString()),
          xlsx.TextCellValue((p['size'] ?? '').toString()),
          xlsx.TextCellValue((p['color'] ?? '').toString()),
          xlsx.TextCellValue(_fmtNum(_toNum(p['stock_ok']), frac: 2)),
          xlsx.TextCellValue(_fmtNum(_toNum(p['stock_defect']), frac: 2)),
          xlsx.TextCellValue(_fmtNum(_toNum(p['cost_price_usd']), frac: 2)),
          xlsx.TextCellValue(_fmtNum(_toNum(p['price_usd']), frac: 2)),
          xlsx.TextCellValue(_fmtNum(_toNum(p['avg_cost_usd']), frac: 2)),
          xlsx.TextCellValue((p['is_active'] == true) ? '1' : '0'),
          xlsx.TextCellValue((p['created'] ?? '').toString()),
        ]);
      }

      final bytes = Uint8List.fromList(excel.encode()!);
      final fileName =
          'products_full_${DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-')}.xlsx';

      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        mimeType: MimeType.microsoftExcel,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel eksport qilindi: $fileName')),
      );
    } catch (e) {
      if (!mounted) return;
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
              if (v == 'xlsx_full') _exportXlsxFull();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, size: 18),
                    SizedBox(width: 8),
                    Text('Export CSV (tezkor)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'xlsx_full',
                child: Row(
                  children: [
                    Icon(Icons.grid_on, size: 18),
                    SizedBox(width: 8),
                    Text('Export Excel (to‘liq, barcha sahifa)'),
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
                      hintText: 'Qidirish (nom / barcode / size / color)',
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
              child: Text(
                'Xato: $_error',
                style: const TextStyle(color: Colors.red),
              ),
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
                      final barcode = (it['barcode'] ?? '').toString();
                      final cat = _catName(it);
                      final price = (it['price_usd']);
                      final stockOk = it['stock_ok'];
                      final stockDef = it['stock_defect'];

                      return Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blueGrey.withOpacity(0.2),
                          ),
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.inventory_2),
                          ),
                          title: Text(
                            name.isEmpty ? '-' : name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (barcode.isNotEmpty) Text('Barcode: $barcode'),
                              Text('Kategoriya: $cat'),
                              Wrap(
                                spacing: 12,
                                children: [
                                  Text('Narx (USD): ${_fmtNum(_toNum(price))}'),
                                  Text(
                                      'OK: ${_fmtNum(_toNum(stockOk), frac: 0)}'),
                                  Text(
                                      'DEF: ${_fmtNum(_toNum(stockDef), frac: 0)}'),
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
}
