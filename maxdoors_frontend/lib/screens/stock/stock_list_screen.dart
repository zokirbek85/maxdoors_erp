import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xlsx;
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class StockListScreen extends StatefulWidget {
  const StockListScreen({super.key});
  @override
  State<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen> {
  bool _loading = true;
  String _error = '';

  // paging
  int _page = 1;
  final int _perPage = 50;

  // filters/search
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _showZero = false;
  bool _useProductsSource = true; // true=products, false=entries
  bool _importAsAbsolute = true;

  // warehouses (entries manbasi uchun)
  List<Map<String, dynamic>> _warehouses = [];
  String? _warehouseId;

  // brand/category filtrlari
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _categories = [];
  String? _supplierId;
  String? _categoryId;

  // rows
  final List<_StockRow> _rows = [];

  final String _expandEntry = 'product,warehouse';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final token = context.read<AuthProvider>().token!;
      await _loadFilterDictionaries(token);
      if (!_useProductsSource) {
        await _loadWarehouses(token);
        await _loadFromEntries(token);
      } else {
        await _loadFromProducts(token);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- DICTS ----------
  Future<void> _loadFilterDictionaries(String token) async {
    try {
      final s = await ApiService.get(
        'collections/suppliers/records?perPage=500&sort=name',
        token: token,
      );
      _suppliers = List<Map<String, dynamic>>.from(s['items'] as List? ?? []);
    } catch (_) {
      _suppliers = [];
    }
    try {
      final c = await ApiService.get(
        'collections/categories/records?perPage=500&sort=name',
        token: token,
      );
      _categories = List<Map<String, dynamic>>.from(c['items'] as List? ?? []);
    } catch (_) {
      _categories = [];
    }
  }

  // ---------- LOADERS ----------
  Future<void> _loadWarehouses(String token) async {
    try {
      final r = await ApiService.get(
        'collections/warehouses/records?perPage=200&sort=name',
        token: token,
      );
      _warehouses = List<Map<String, dynamic>>.from(r['items'] as List? ?? []);
    } catch (_) {
      _warehouses = [];
    }
  }

  Future<void> _loadFromProducts(String token) async {
    _rows.clear();
    int page = 1;
    final out = <Map<String, dynamic>>[];

    while (true) {
      final url =
          'collections/products/records?perPage=200&page=$page&sort=name&expand=supplier,category';
      final res = await ApiService.get(url, token: token);
      final items =
          List<Map<String, dynamic>>.from(res['items'] as List? ?? []);
      out.addAll(items);
      final total = (res['totalItems'] as num?)?.toInt() ?? out.length;
      if (out.length >= total || items.isEmpty) break;
      page++;
      if (page > 200) break;
    }

    final rows = <_StockRow>[];
    for (final p in out) {
      final name = (p['name'] ?? p['title'] ?? p['id']).toString();
      final code = (p['code'] ?? p['sku'] ?? p['article'] ?? '').toString();
      final barcode = (p['barcode'] ?? '').toString();
      final type = (p['type'] ?? '').toString();
      final size = (p['size'] ?? '').toString();
      final color = (p['color'] ?? '').toString();
      final supplierName = _expandName(p, 'supplier');
      final categoryName = _expandName(p, 'category');
      final supplierId = (p['supplier'] ?? '').toString();
      final categoryId = (p['category'] ?? '').toString();
      final ok = _toDouble(p['stock_ok']);
      final defect = _toDouble(p['stock_defect']);
      final sale = _toDouble(p['sale_price_usd'] ?? p['price_usd']);
      final cost = _toDouble(p['cost_price_usd']);

      // brand/category filtrlari
      if (_supplierId != null &&
          _supplierId!.isNotEmpty &&
          supplierId != _supplierId) {
        continue;
      }
      if (_categoryId != null &&
          _categoryId!.isNotEmpty &&
          categoryId != _categoryId) {
        continue;
      }

      // qidirish
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final hay =
            ('$name $code $barcode $type $size $color $supplierName $categoryName')
                .toLowerCase();
        if (!hay.contains(q)) continue;
      }

      if (!_showZero && ok.abs() < 0.0001 && defect.abs() < 0.0001) continue;

      rows.add(_StockRow(
        productId: p['id'].toString(),
        productName: name,
        productCode: code,
        warehouseId: '',
        warehouseName: '',
        qtyOk: ok,
        qtyDefect: defect,
        priceUsd: sale,
        costUsd: cost,
        barcode: barcode,
        type: type,
        size: size,
        color: color,
        supplierName: supplierName,
        categoryName: categoryName,
        supplierId: supplierId,
        categoryId: categoryId,
      ));
    }

    rows.sort((a, b) => b.qtyOk.compareTo(a.qtyOk));

    setState(() {
      _rows
        ..clear()
        ..addAll(rows);
      _page = 1;
    });
  }

  Future<void> _loadFromEntries(String token) async {
    _rows.clear();
    final all = await _fetchAllEntries(token);
    final map = <String, _Agg>{};

    for (final it in all) {
      final productId = it['product']?.toString() ?? '';
      if (productId.isEmpty) continue;

      final warehouseId = it['warehouse']?.toString() ?? '';
      if (_warehouseId != null &&
          _warehouseId!.isNotEmpty &&
          warehouseId != _warehouseId) {
        continue;
      }

      final q = _signedQty(it);
      if (q == 0) continue;

      final isDefect = (it['is_defect'] == true) ||
          (it['type']?.toString().toLowerCase() == 'defect');

      final exp = it['expand'];
      Map<String, dynamic>? expProduct;
      Map<String, dynamic>? expWarehouse;
      if (exp is Map) {
        if (exp['product'] is Map) {
          expProduct = Map<String, dynamic>.from(exp['product']);
        }
        if (exp['warehouse'] is Map) {
          expWarehouse = Map<String, dynamic>.from(exp['warehouse']);
        }
      }

      final supplierId = (expProduct?['supplier'] ?? '').toString();
      final categoryId = (expProduct?['category'] ?? '').toString();
      final supplierName = _relName(expProduct, 'supplier');
      final categoryName = _relName(expProduct, 'category');

      // brand/category filtrlari
      if (_supplierId != null &&
          _supplierId!.isNotEmpty &&
          supplierId != _supplierId) {
        continue;
      }
      if (_categoryId != null &&
          _categoryId!.isNotEmpty &&
          categoryId != _categoryId) {
        continue;
      }

      final key = '$productId|$warehouseId';
      map.putIfAbsent(
        key,
        () => _Agg(
          productId: productId,
          warehouseId: warehouseId,
          productName: _productName(expProduct, productId),
          productCode: _productCode(expProduct),
          warehouseName: _warehouseNameFromExpand(expWarehouse, warehouseId),
          priceUsd: _priceUsdFromProduct(expProduct),
          costUsd: _costUsdFromProduct(expProduct),
          barcode: (expProduct?['barcode'] ?? '').toString(),
          type: (expProduct?['type'] ?? '').toString(),
          size: (expProduct?['size'] ?? '').toString(),
          color: (expProduct?['color'] ?? '').toString(),
          supplierName: supplierName,
          categoryName: categoryName,
          supplierId: supplierId,
          categoryId: categoryId,
        ),
      );

      if (isDefect) {
        map[key]!.qtyDefect += q;
      } else {
        map[key]!.qtyOk += q;
      }
    }

    var rows = map.values.toList();

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      rows.retainWhere((r) =>
          r.productName.toLowerCase().contains(q) ||
          r.productCode.toLowerCase().contains(q) ||
          r.barcode.toLowerCase().contains(q) ||
          r.color.toLowerCase().contains(q) ||
          r.size.toLowerCase().contains(q) ||
          r.supplierName.toLowerCase().contains(q) ||
          r.categoryName.toLowerCase().contains(q));
    }

    if (!_showZero) {
      rows.removeWhere(
          (r) => r.qtyOk.abs() < 0.0001 && r.qtyDefect.abs() < 0.0001);
    }

    rows.sort((a, b) => b.qtyOk.compareTo(a.qtyOk));

    setState(() {
      _rows
        ..clear()
        ..addAll(rows.map((a) => _StockRow.fromAgg(a)));
      _page = 1;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchAllEntries(String token) async {
    int page = 1;
    final out = <Map<String, dynamic>>[];
    while (true) {
      final url =
          'collections/stock_entry_items/records?perPage=200&page=$page&sort=-created&expand=$_expandEntry';
      final res = await ApiService.get(url, token: token);
      final items =
          List<Map<String, dynamic>>.from(res['items'] as List? ?? []);
      out.addAll(items);

      final total = (res['totalItems'] as num?)?.toInt() ?? out.length;
      if (out.length >= total || items.isEmpty) break;
      page++;
      if (page > 200) break;
    }
    return out;
  }

  // ---------- HELPERS ----------
  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  double _signedQty(Map<String, dynamic> row) {
    final type = (row['type'] ?? row['direction'])?.toString().toLowerCase();
    final hasType = type == 'in' || type == 'out';
    final hasQtyIn = row.containsKey('qty_in') || row.containsKey('qtyIn');
    final hasQtyOut = row.containsKey('qty_out') || row.containsKey('qtyOut');

    if (hasType) {
      final q = _toDouble(row['qty'] ?? row['quantity'] ?? row['delta']);
      return type == 'out' ? -q : q;
    }
    if (hasQtyIn || hasQtyOut) {
      final qi = _toDouble(row['qty_in'] ?? row['qtyIn']);
      final qo = _toDouble(row['qty_out'] ?? row['qtyOut']);
      return qi - qo;
    }
    return _toDouble(row['qty'] ?? row['quantity'] ?? row['delta']);
  }

  String _expandName(Map<String, dynamic> row, String rel) {
    final exp = row['expand'];
    if (exp is Map && exp[rel] is Map && exp[rel]['name'] != null) {
      return exp[rel]['name'].toString();
    }
    return '-';
  }

  String _productName(Map<String, dynamic>? expProduct, String productId) {
    if (expProduct != null) {
      final nm = expProduct['name']?.toString();
      if (nm != null && nm.isNotEmpty) return nm;
    }
    return productId;
  }

  String _productCode(Map<String, dynamic>? expProduct) {
    if (expProduct == null) return '';
    final code =
        expProduct['code'] ?? expProduct['sku'] ?? expProduct['article'];
    return code?.toString() ?? '';
  }

  String _warehouseNameFromExpand(
      Map<String, dynamic>? expWarehouse, String wid) {
    if (expWarehouse != null) {
      final nm = expWarehouse['name']?.toString();
      if (nm != null && nm.isNotEmpty) return nm;
    }
    return wid;
  }

  double _priceUsdFromProduct(Map<String, dynamic>? expProduct) {
    if (expProduct == null) return 0.0;
    final raw = expProduct['sale_price_usd'] ??
        expProduct['price_usd'] ??
        expProduct['recommended_price_usd'];
    return _toDouble(raw);
  }

  double _costUsdFromProduct(Map<String, dynamic>? expProduct) {
    if (expProduct == null) return 0.0;
    return _toDouble(expProduct['cost_price_usd']);
  }

  String _relName(Map<String, dynamic>? expOwner, String rel) {
    if (expOwner != null &&
        expOwner['expand'] is Map &&
        expOwner['expand'][rel] is Map) {
      final nm = expOwner['expand'][rel]['name']?.toString();
      if (nm != null && nm.isNotEmpty) return nm;
    }
    return '';
  }

  String _normalizeType(String t) {
    final s = (t).trim().toUpperCase();
    if (s == 'PG' || s == 'ПГ') return 'pg';
    if (s == 'PO' || s == 'ПО') return 'po';
    return s.toLowerCase();
  }

  String _fmtNum(num v, {int frac = 2}) => v.toStringAsFixed(frac);

  Future<void> _saveBytes(Uint8List bytes, String fileName, MimeType mt) async {
    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: bytes,
      //ext: fileName.split('.').last,
      mimeType: mt,
    );
  }

  // ---------- EXPORT (unchanged core) ----------
  Future<void> _exportCsv() async {
    try {
      await _bootstrap();
      if (_rows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Ma’lumot yo‘q')));
        }
        return;
      }
      final rows = <List<dynamic>>[
        [
          'Brand',
          'Category',
          'Product',
          'Barcode',
          'Type',
          'Size',
          'Color',
          'Code/SKU',
          'Qty OK',
          'Qty Defect',
          'Cost USD',
          'Sale USD',
          'Amount USD'
        ]
      ];
      for (final r in _rows) {
        rows.add([
          r.supplierName,
          r.categoryName,
          r.productName,
          r.barcode,
          r.type,
          r.size,
          r.color,
          r.productCode,
          _fmtNum(r.qtyOk),
          _fmtNum(r.qtyDefect),
          _fmtNum(r.costUsd),
          _fmtNum(r.priceUsd),
          _fmtNum(r.qtyOk * r.priceUsd),
        ]);
      }
      final csv = const ListToCsvConverter().convert(rows);
      final bytes = Uint8List.fromList(utf8.encode(csv));
      final fileName =
          'stock_export_${DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-')}.csv';
      await _saveBytes(bytes, fileName, MimeType.csv);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('CSV eksport qilindi ($fileName)')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('CSV xatosi: $e')));
      }
    }
  }

  xlsx.CellValue _cv(dynamic v) {
    if (v == null) return xlsx.TextCellValue('');
    if (v is num) return xlsx.DoubleCellValue(v.toDouble());
    // Sana/string va boshqalar:
    return xlsx.TextCellValue(v.toString());
  }

  Future<void> _exportXlsx() async {
    try {
      await _bootstrap();

      if (_rows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Ma’lumot yo‘q')));
        }
        return;
      }

      final excel = xlsx.Excel.createExcel();
      final sheet = excel['Stock'];

      // Header (faqat TextCellValue)
      sheet.appendRow([
        xlsx.TextCellValue('Brand'),
        xlsx.TextCellValue('Category'),
        xlsx.TextCellValue('Product'),
        xlsx.TextCellValue('Barcode'),
        xlsx.TextCellValue('Type'),
        xlsx.TextCellValue('Size'),
        xlsx.TextCellValue('Color'),
        xlsx.TextCellValue('Code/SKU'),
        xlsx.TextCellValue('Qty OK'),
        xlsx.TextCellValue('Qty Defect'),
        xlsx.TextCellValue('Cost USD'),
        xlsx.TextCellValue('Sale USD'),
        xlsx.TextCellValue('Amount USD'),
      ]);

      // Rows (CellValue mix — numberlar DoubleCellValue bo‘ladi)
      for (final r in _rows) {
        sheet.appendRow([
          _cv(r.supplierName),
          _cv(r.categoryName),
          _cv(r.productName),
          _cv(r.barcode),
          _cv(r.type),
          _cv(r.size),
          _cv(r.color),
          _cv(r.productCode),
          _cv(r.qtyOk),
          _cv(r.qtyDefect),
          _cv(r.costUsd),
          _cv(r.priceUsd),
          _cv(r.qtyOk * r.priceUsd),
        ]);
      }

      final bytes = Uint8List.fromList(excel.encode()!);
      final fileName =
          'stock_export_${DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-')}.xlsx';

      await _saveBytes(bytes, fileName, MimeType.microsoftExcel);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel eksport qilindi ($fileName)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Excel xatosi: $e')));
      }
    }
  }

  // ---------- IMPORT (unchanged core) ----------
  Future<void> _importFile() async {
    try {
      final pick = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
      );
      if (pick == null || pick.files.isEmpty) return;
      final file = pick.files.single;
      final bytes = file.bytes!;
      final name = (file.name).toLowerCase();

      final rows = <Map<String, dynamic>>[];
      if (name.endsWith('.xlsx')) {
        final ex = xlsx.Excel.decodeBytes(bytes);
        final sheet = ex.tables[ex.tables.keys.first]!;
        final header = sheet.rows.first
            .map((c) => (c?.value ?? '').toString().trim())
            .toList();
        for (int i = 1; i < sheet.maxRows; i++) {
          final r = sheet.rows[i];
          final m = <String, dynamic>{};
          for (int j = 0; j < header.length; j++) {
            final key = header[j];
            final val = j < r.length ? (r[j]?.value ?? '') : '';
            m[key] = val;
          }
          rows.add(m);
        }
      } else {
        final csvStr = utf8.decode(bytes);
        final list = const CsvToListConverter().convert(csvStr);
        if (list.isEmpty) return;
        final header = list.first.map((e) => e.toString().trim()).toList();
        for (int i = 1; i < list.length; i++) {
          final r = list[i];
          final m = <String, dynamic>{};
          for (int j = 0; j < header.length; j++) {
            m[header[j]] = j < r.length ? r[j] : '';
          }
          rows.add(m);
        }
      }

      if (rows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Jadval bo‘sh')));
        }
        return;
      }

      final token = context.read<AuthProvider>().token!;
      final batchId = 'import_${DateTime.now().millisecondsSinceEpoch}';

      int okCount = 0, newProd = 0, updProd = 0;

      for (int i = 0; i < rows.length; i++) {
        final r = rows[i];

        String supplierName = _asStr(r, ['brand', 'supplier']);
        String categoryName = _asStr(r, ['category']);
        String nameP = _asStr(r, ['product_name', 'name', 'product']);
        String barcode = _asStr(r, ['barcode']);
        String type = _asStr(r, ['type']);
        String size = _asStr(r, ['size']);
        String color = _asStr(r, ['color']);

        final qtyOk = _asNum(r, ['qty_ok', 'ok', 'qty']);
        final qtyDef = _asNum(r, ['qty_defect', 'defect']);
        final costUsd = _asNum(r, ['cost_price_usd', 'cost_usd', 'cost']);
        final saleUsd = _asNum(r, ['sale_price_usd', 'price_usd', 'price']);

        if (type.isEmpty) type = _extractTypeFromName(nameP);
        if (size.isEmpty) size = _extractSizeFromName(nameP);
        if (color.isEmpty) color = _extractColorFromName(nameP);
        if (barcode.isEmpty) barcode = _genBarcode13();

        final normType = _normalizeType(type);
        final supplierId =
            await _ensureByName('suppliers', supplierName, token);
        final categoryId =
            await _ensureByName('categories', categoryName, token);

        final prod = await _findProduct(barcode, nameP, supplierId, token);
        String productId;
        double prevOk = 0, prevDef = 0;

        final double priceForSchema =
            saleUsd > 0 ? saleUsd : (costUsd > 0 ? costUsd : 0.0);

        final payload = {
          'name': nameP,
          'supplier': supplierId,
          'category': categoryId,
          'barcode': barcode,
          'type': normType,
          'size': size,
          'color': color,
          'cost_price_usd': costUsd,
          'sale_price_usd': saleUsd,
          'price_usd': priceForSchema,
          'is_active': true,
        };

        if (prod == null) {
          payload['stock_ok'] = qtyOk;
          payload['stock_defect'] = qtyDef;
          final created = await ApiService.post(
              'collections/products/records', payload,
              token: token);
          productId = created['id'].toString();
          newProd++;

          await _tryCreateEntryItem(productId, qtyOk, false, token);
          await _tryCreateEntryItem(productId, qtyDef, true, token);

          await _writeStockLog(
              productId, qtyOk, qtyDef, 'import', '$batchId:$i', token);
        } else {
          productId = prod['id'].toString();
          prevOk = _toDouble(prod['stock_ok']);
          prevDef = _toDouble(prod['stock_defect']);

          if (_importAsAbsolute) {
            final deltaOk = qtyOk - prevOk;
            final deltaDef = qtyDef - prevDef;
            payload['stock_ok'] = qtyOk;
            payload['stock_defect'] = qtyDef;
            await _safePatchProduct(productId, payload, token);
            await _tryCreateEntryItem(productId, deltaOk, false, token);
            await _tryCreateEntryItem(productId, deltaDef, true, token);
            if (deltaOk.abs() > 0.0001 || deltaDef.abs() > 0.0001) {
              await _writeStockLog(
                  productId, deltaOk, deltaDef, 'import', '$batchId:$i', token);
            }
          } else {
            final newOk = prevOk + qtyOk;
            final newDef = prevDef + qtyDef;
            payload['stock_ok'] = newOk;
            payload['stock_defect'] = newDef;
            await _safePatchProduct(productId, payload, token);
            await _tryCreateEntryItem(productId, qtyOk, false, token);
            await _tryCreateEntryItem(productId, qtyDef, true, token);
            if (qtyOk.abs() > 0.0001 || qtyDef.abs() > 0.0001) {
              await _writeStockLog(
                  productId, qtyOk, qtyDef, 'import', '$batchId:$i', token);
            }
          }
          updProd++;
        }
        okCount++;
        if (mounted && okCount % 50 == 0) setState(() {});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Import tugadi: $okCount qator • yangi=$newProd • yangilangan=$updProd')),
        );
        await _bootstrap();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Import xatosi: $e')));
      }
    }
  }

  Future<void> _safePatchProduct(
      String id, Map<String, dynamic> payload, String token) async {
    try {
      await ApiService.patch('collections/products/records/$id', payload,
          token: token);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('404') || msg.contains('not found')) {
        await ApiService.post('collections/products/records', payload,
            token: token);
      } else {
        rethrow;
      }
    }
  }

  Future<void> _tryCreateEntryItem(
      String productId, double qty, bool isDefect, String token) async {
    try {
      if (qty.abs() < 0.0001) return;
      await ApiService.post(
          'collections/stock_entry_items/records',
          {
            'product': productId,
            'type': 'in',
            'qty': qty,
            'is_defect': isDefect
          },
          token: token);
    } catch (_) {}
  }

  String _asStr(Map<String, dynamic> row, List<String> keys) {
    for (final k in keys) {
      final v = row[k] ?? row[k.toUpperCase()] ?? row[_camel(k)];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return '';
  }

  double _asNum(Map<String, dynamic> row, List<String> keys) {
    final s = _asStr(row, keys);
    return _toDouble(s);
  }

  String _camel(String s) {
    final parts = s.split('_');
    return parts.first +
        parts.skip(1).map((e) => e[0].toUpperCase() + e.substring(1)).join();
  }

  String _extractTypeFromName(String name) {
    final n = name.toUpperCase();
    if (n.contains('ПГ')) return 'PG';
    if (n.contains('ПО')) return 'PO';
    if (n.contains('PG')) return 'PG';
    if (n.contains('PO')) return 'PO';
    return '';
  }

  String _extractSizeFromName(String name) {
    final re = RegExp(r'(\d+)\s*мм', caseSensitive: false);
    final m = re.firstMatch(name);
    return m != null ? '${m.group(1)}мм' : '';
  }

  String _extractColorFromName(String name) {
    final re = RegExp(r'([A-Za-zА-Яа-яЁё\s\-]+)\s+(ПГ|ПО|PG|PO)\b');
    final m = re.firstMatch(name);
    if (m != null) {
      final s = (m.group(1) ?? '').trim();
      if (s.isNotEmpty && s.length <= 30) return s;
    }
    return '';
  }

  String _genBarcode13() {
    final rnd = Random();
    final buf = StringBuffer();
    for (int i = 0; i < 13; i++) {
      buf.write(rnd.nextInt(10));
    }
    return buf.toString();
  }

  Future<String> _ensureByName(
      String collection, String name, String token) async {
    if (name.trim().isEmpty) return '';
    final filter = Uri.encodeComponent("name='${name.replaceAll("'", r"\'")}'");
    final url =
        'collections/$collection/records?perPage=1&filter=$filter&sort=-created';
    final res = await ApiService.get(url, token: token);
    final items = (res['items'] as List?) ?? const [];
    if (items.isNotEmpty) return items.first['id'].toString();

    final created = await ApiService.post(
        'collections/$collection/records', {'name': name.trim()},
        token: token);
    return created['id'].toString();
  }

  Future<Map<String, dynamic>?> _findProduct(
      String barcode, String name, String supplierId, String token) async {
    Map<String, dynamic>? found;
    if (barcode.trim().isNotEmpty) {
      final f =
          Uri.encodeComponent("barcode='${barcode.replaceAll("'", r"\'")}'");
      final r = await ApiService.get(
          'collections/products/records?perPage=1&filter=$f&expand=supplier,category',
          token: token);
      final items = (r['items'] as List?) ?? const [];
      if (items.isNotEmpty) found = Map<String, dynamic>.from(items.first);
    }
    if (found != null) return found;

    final safeName = name.replaceAll("'", r"\'");
    final parts = <String>["name='$safeName'"];
    if (supplierId.isNotEmpty) parts.add("supplier='$supplierId'");
    final f2 = Uri.encodeComponent(parts.join(' && '));
    final r2 = await ApiService.get(
        'collections/products/records?perPage=1&filter=$f2&expand=supplier,category',
        token: token);
    final items2 = (r2['items'] as List?) ?? const [];
    if (items2.isNotEmpty) return Map<String, dynamic>.from(items2.first);
    return null;
  }

  Future<void> _writeStockLog(String productId, double deltaOk, double deltaDef,
      String reason, String refId, String token) async {
    if (deltaOk.abs() < 0.0001 && deltaDef.abs() < 0.0001) return;
    await ApiService.post(
        'collections/stock_log/records',
        {
          'product': productId,
          'delta_ok': deltaOk,
          'delta_defect': deltaDef,
          'reason': reason,
          'ref_id': refId,
          'ts': DateTime.now().toIso8601String(),
        },
        token: token);
  }

  // ---------- QUICK EDIT ----------
  Future<void> _openEditDialog(_StockRow r) async {
    final okCtrl = TextEditingController(text: _fmtNum(r.qtyOk, frac: 2));
    final defCtrl = TextEditingController(text: _fmtNum(r.qtyDefect, frac: 2));
    final saleCtrl = TextEditingController(text: _fmtNum(r.priceUsd, frac: 2));
    final costCtrl = TextEditingController(text: _fmtNum(r.costUsd, frac: 2));
    final barcodeCtrl = TextEditingController(text: r.barcode);
    final typeCtrl = TextEditingController(text: r.type);
    final sizeCtrl = TextEditingController(text: r.size);
    final colorCtrl = TextEditingController(text: r.color);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            Text(r.productName, maxLines: 2, overflow: TextOverflow.ellipsis),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(child: _numField('Qty OK', okCtrl)),
                const SizedBox(width: 8),
                Expanded(child: _numField('Qty DEF', defCtrl)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _numField('Sale USD', saleCtrl)),
                const SizedBox(width: 8),
                Expanded(child: _numField('Cost USD', costCtrl)),
              ]),
              const SizedBox(height: 8),
              _textField('Barcode', barcodeCtrl),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _textField('Type', typeCtrl)),
                const SizedBox(width: 8),
                Expanded(child: _textField('Size', sizeCtrl)),
              ]),
              const SizedBox(height: 8),
              _textField('Color', colorCtrl),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Bekor')),
          ElevatedButton(
            onPressed: () async {
              try {
                final token = context.read<AuthProvider>().token!;
                final newOk = _toDouble(okCtrl.text);
                final newDef = _toDouble(defCtrl.text);
                final newSale = _toDouble(saleCtrl.text);
                final newCost = _toDouble(costCtrl.text);

                final payload = {
                  'stock_ok': newOk,
                  'stock_defect': newDef,
                  'sale_price_usd': newSale,
                  'cost_price_usd': newCost,
                  'barcode': barcodeCtrl.text.trim(),
                  'type': _normalizeType(typeCtrl.text.trim()),
                  'size': sizeCtrl.text.trim(),
                  'color': colorCtrl.text.trim(),
                };

                final deltaOk = newOk - r.qtyOk;
                final deltaDef = newDef - r.qtyDefect;

                await ApiService.patch(
                  'collections/products/records/${r.productId}',
                  payload,
                  token: token,
                );

                if (deltaOk.abs() > 0.0001 || deltaDef.abs() > 0.0001) {
                  await _writeStockLog(
                    r.productId,
                    deltaOk,
                    deltaDef,
                    'adjustment',
                    'quick_edit',
                    token,
                  );
                }

                if (mounted) {
                  Navigator.pop(ctx);
                  await _bootstrap();
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Saqlandi')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Saqlash xatosi: $e')));
                }
              }
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
  }

  Widget _numField(String label, TextEditingController c) => TextField(
        controller: c,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true, signed: false),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      );

  Widget _textField(String label, TextEditingController c) => TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      );

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final start = (_page - 1) * _perPage;
    final end = min(start + _perPage, _rows.length);
    final visible = _rows.sublist(start, end);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mahsulotlar qoldig‘i'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _bootstrap),
          IconButton(
              icon: const Icon(Icons.upload_file), onPressed: _importFile),
          IconButton(icon: const Icon(Icons.table_view), onPressed: _exportCsv),
          IconButton(icon: const Icon(Icons.grid_on), onPressed: _exportXlsx),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 340,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Qidirish (nom/kod/barcode/rang/size)',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) {
                      setState(() => _query = _searchCtrl.text.trim());
                      _bootstrap();
                    },
                  ),
                ),
                FilterChip(
                  selected: _useProductsSource,
                  label: const Text('Manba: Products'),
                  onSelected: (v) {
                    setState(() => _useProductsSource = true);
                    _bootstrap();
                  },
                ),
                FilterChip(
                  selected: !_useProductsSource,
                  label: const Text('Manba: Entry items'),
                  onSelected: (v) {
                    setState(() => _useProductsSource = false);
                    _bootstrap();
                  },
                ),
                if (!_useProductsSource)
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      value: _warehouseId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Ombor',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Barchasi')),
                        ..._warehouses.map((w) => DropdownMenuItem<String>(
                              value: w['id'].toString(),
                              child: Text(w['name']?.toString() ?? w['id']),
                            )),
                      ],
                      onChanged: (v) {
                        setState(() => _warehouseId = v);
                        _bootstrap();
                      },
                    ),
                  ),

                // BRAND filter
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
                      ..._suppliers.map((s) => DropdownMenuItem<String>(
                            value: s['id'].toString(),
                            child: Text(s['name']?.toString() ?? s['id']),
                          )),
                    ],
                    onChanged: (v) {
                      setState(() => _supplierId = v);
                      _bootstrap();
                    },
                  ),
                ),
                // CATEGORY filter
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
                      ..._categories.map((c) => DropdownMenuItem<String>(
                            value: c['id'].toString(),
                            child: Text(c['name']?.toString() ?? c['id']),
                          )),
                    ],
                    onChanged: (v) {
                      setState(() => _categoryId = v);
                      _bootstrap();
                    },
                  ),
                ),

                FilterChip(
                  selected: _showZero,
                  label: const Text('0 qoldiqni ko‘rsatish'),
                  onSelected: (v) {
                    setState(() => _showZero = v);
                    _bootstrap();
                  },
                ),
                FilterChip(
                  selected: _importAsAbsolute,
                  label: const Text('Import: absolute'),
                  onSelected: (v) => setState(() => _importAsAbsolute = v),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _query = _searchCtrl.text.trim());
                    _bootstrap();
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
            child: visible.isEmpty && !_loading
                ? const Center(child: Text('Ma’lumot topilmadi'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final r = visible[i];
                      return Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(child: Icon(Icons.inventory_2)),
                            const SizedBox(width: 12),
                            // LEFT: title + subtitle
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.productName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 4,
                                    children: [
                                      if (r.productCode.isNotEmpty)
                                        Text('Kod: ${r.productCode}'),
                                      if (r.barcode.isNotEmpty)
                                        Text('Barcode: ${r.barcode}'),
                                      Text(
                                          'Brand: ${r.supplierName.isEmpty ? '-' : r.supplierName}'),
                                      Text(
                                          'Kategoriya: ${r.categoryName.isEmpty ? '-' : r.categoryName}'),
                                      if (!_useProductsSource)
                                        Text(
                                            'Ombor: ${r.warehouseName.isEmpty ? '-' : r.warehouseName}'),
                                      if (r.type.isNotEmpty ||
                                          r.size.isNotEmpty ||
                                          r.color.isNotEmpty)
                                        Text(
                                            'T/S/C: ${r.type.isEmpty ? '-' : r.type} / ${r.size.isEmpty ? '-' : r.size} / ${r.color.isEmpty ? '-' : r.color}'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // RIGHT: trailing (no overflow)
                            SizedBox(
                              width: 150,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'OK: ${_fmtNum(r.qtyOk, frac: 2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: (r.qtyOk > 0)
                                          ? Colors.green.shade700
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                  if (r.qtyDefect.abs() >= 0.0001)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        'DEF: ${_fmtNum(r.qtyDefect, frac: 2)}',
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  if (r.priceUsd > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        '\$${_fmtNum(r.priceUsd)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: IconButton(
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Tahrirlash',
                                      icon: const Icon(Icons.edit, size: 18),
                                      onPressed: () => _openEditDialog(r),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          if (_rows.length > _perPage)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _page > 1 ? () => setState(() => _page--) : null,
                    child: const Text('Oldingi'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('$_page'),
                  ),
                  TextButton(
                    onPressed: (_page * _perPage) < _rows.length
                        ? () => setState(() => _page++)
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

// ------- Inner models -------
class _Agg {
  final String productId;
  final String warehouseId;
  final String productName;
  final String productCode;
  final String warehouseName;
  final String barcode;
  final String type;
  final String size;
  final String color;
  final String supplierName;
  final String categoryName;
  final String supplierId;
  final String categoryId;
  double qtyOk;
  double qtyDefect;
  final double priceUsd;
  final double costUsd;

  _Agg({
    required this.productId,
    required this.warehouseId,
    required this.productName,
    required this.productCode,
    required this.warehouseName,
    required this.barcode,
    required this.type,
    required this.size,
    required this.color,
    required this.supplierName,
    required this.categoryName,
    required this.supplierId,
    required this.categoryId,
    required this.priceUsd,
    required this.costUsd,
    this.qtyOk = 0.0,
    this.qtyDefect = 0.0,
  });
}

class _StockRow {
  final String productId;
  final String productName;
  final String productCode;
  final String warehouseId;
  final String warehouseName;
  final double qtyOk;
  final double qtyDefect;
  final double priceUsd;
  final double costUsd;
  final String barcode;
  final String type;
  final String size;
  final String color;
  final String supplierName;
  final String categoryName;
  final String supplierId;
  final String categoryId;

  _StockRow({
    required this.productId,
    required this.productName,
    required this.productCode,
    required this.warehouseId,
    required this.warehouseName,
    required this.qtyOk,
    required this.qtyDefect,
    required this.priceUsd,
    required this.costUsd,
    required this.barcode,
    required this.type,
    required this.size,
    required this.color,
    required this.supplierName,
    required this.categoryName,
    this.supplierId = '',
    this.categoryId = '',
  });

  factory _StockRow.fromAgg(_Agg a) => _StockRow(
        productId: a.productId,
        productName: a.productName,
        productCode: a.productCode,
        warehouseId: a.warehouseId,
        warehouseName: a.warehouseName,
        qtyOk: a.qtyOk,
        qtyDefect: a.qtyDefect,
        priceUsd: a.priceUsd,
        costUsd: a.costUsd,
        barcode: a.barcode,
        type: a.type,
        size: a.size,
        color: a.color,
        supplierName: a.supplierName,
        categoryName: a.categoryName,
        supplierId: a.supplierId,
        categoryId: a.categoryId,
      );
}
