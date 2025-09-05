// lib/services/product_import_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xlsx;
import 'package:path_provider/path_provider.dart';

import '../services/api_service.dart';

/// === Maydon nomlari xaritasi (PB sxemaga mos) ===============================
/// Sxema: products: supplier(rel, opt), category(rel, req), name(req), barcode(unique),
/// type(select: pg/po), size, color, price_usd(req), cost_price_usd, is_active(req),
/// stock_ok, stock_defect, avg_cost_usd, ...
class ProductFields {
  // Products collection field names
  static const String supplier = 'supplier'; // rel
  static const String category = 'category'; // rel (required)
  static const String name = 'name'; // required
  static const String barcode = 'barcode'; // unique (ixtiyoriy)
  static const String type = 'type'; // select (pg/po)
  static const String size = 'size';
  static const String color = 'color';
  static const String priceUsd =
      'price_usd'; // required (sale_price_usd kiradi)
  static const String costPriceUsd = 'cost_price_usd';
  static const String avgCostUsd =
      'avg_cost_usd'; // bu yerga amount_usd yozamiz (agar kerak bo‘lsa)
  static const String stockOk = 'stock_ok';
  static const String stockDefect = 'stock_defect';
  static const String isActive = 'is_active'; // required

  // Reference collections (fallback bilan)
  static const List<String> categoryCollections = [
    'categories',
    'product_categories'
  ];
  static const List<String> supplierCollections = ['suppliers'];

  // Reference name field
  static const String refNameField = 'name';
}

/// === CSV/XLSX ustunlari =====================================================
/// supplier, category, name, barcode, type, size, color,
/// qty_ok, qty_defect, cost_price_usd, sale_price_usd, amount_usd, is_active
class ProductImportService {
  final String token;

  /// Topilmasa kategoriya/supplierni yaratish (true bo'lsa yaratadi)
  final bool createMissingRefs;

  ProductImportService({required this.token, this.createMissingRefs = false});

  /// CSV shablonini foydalanuvchi papkasiga yozadi (yangi format)
  static Future<File> writeTemplate() async {
    final headers = [
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
    ];
    final example = [
      [
        'LesKom',
        'Ichki eshiklar',
        'Eshik Premium-01',
        'MD-1234567890',
        'pg',
        '80x200',
        'white',
        '10',
        '0',
        '80',
        '120',
        '85',
        '1'
      ],
      [
        'LesKom',
        'Ichki eshiklar',
        'Standart',
        '',
        'po',
        '80x200',
        'oak',
        '3',
        '1',
        '60',
        '95',
        '70',
        '1'
      ],
    ];
    final dir = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/products_template.xlsx');

    final excel = xlsx.Excel.createExcel();
    final sheet = excel['Template'];
    sheet.appendRow(headers.map((e) => xlsx.TextCellValue(e)).toList());
    for (final row in example) {
      sheet
          .appendRow(row.map((e) => xlsx.TextCellValue(e.toString())).toList());
    }
    final bytes = excel.encode()!;
    await file.writeAsBytes(bytes);
    return file;
  }

  // -------------------- Helpers: HTTP wrappers ------------------------------

  Future<List<Map<String, dynamic>>> _fetchAll(String collection,
      {String sort = 'name'}) async {
    final List<Map<String, dynamic>> all = [];
    var page = 1;
    while (true) {
      final res = await ApiService.get(
        'collections/$collection/records?perPage=200&page=$page&sort=$sort',
        token: token,
      );
      final items = List<Map<String, dynamic>>.from(res['items'] as List);
      all.addAll(items);
      final total = (res['totalItems'] as num?)?.toInt() ?? items.length;
      if (all.length >= total || items.isEmpty) break;
      page++;
    }
    return all;
  }

  Future<List<Map<String, dynamic>>> _fetchAllAny(
      List<String> collections) async {
    Object? lastErr;
    for (final name in collections) {
      try {
        return await _fetchAll(name);
      } catch (e) {
        lastErr = e;
      }
    }
    throw Exception(
        'Kolleksiya topilmadi (${collections.join(" yoki ")}). So‘nggi xato: $lastErr');
  }

  Future<Map<String, String>> _buildNameToIdAny(List<String> collections,
      {String nameField = ProductFields.refNameField}) async {
    final list = await _fetchAllAny(collections);
    final map = <String, String>{};
    for (final it in list) {
      final label = (it[nameField] ?? '').toString().trim();
      if (label.isNotEmpty) map[label.toLowerCase()] = it['id'] as String;
    }
    return map;
  }

  Future<String> _ensureRefId({
    required String collection,
    required String name,
    required Map<String, String> cache,
    String nameField = ProductFields.refNameField,
  }) async {
    final key = name.trim().toLowerCase();
    if (cache.containsKey(key)) {
      return cache[key]!;
    }
    if (!createMissingRefs) {
      throw StateError("'$name' ($collection) topilmadi");
    }
    final res = await ApiService.post(
      'collections/$collection/records',
      {nameField: name},
      token: token,
    );
    final id = res['id'] as String;
    cache[key] = id;
    return id;
  }

  // -------------------- CSV/XLSX parsing ------------------------------------

  Future<_ParsedProductsSheet> parseCsvOrXlsx(
      {File? file, List<int>? bytes}) async {
    if (bytes != null ||
        (file != null && file.path.toLowerCase().endsWith('.csv'))) {
      return _parseCsv(bytes: bytes, file: file);
    } else if (file != null && file.path.toLowerCase().endsWith('.xlsx')) {
      return _parseXlsx(file: file);
    } else {
      throw StateError('Fayl .csv yoki .xlsx bo‘lishi kerak');
    }
  }

  Future<_ParsedProductsSheet> _parseCsv({List<int>? bytes, File? file}) async {
    final content = bytes != null
        ? utf8.decode(bytes)
        : await file?.readAsString(encoding: const Utf8Codec()) ?? '';
    if (content.isEmpty) {
      throw StateError('CSV bo'sh yoki o'qilib bo'lmadi');
    }
    final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
        .convert(content);
    if (rows.isEmpty) throw StateError('CSV bo‘sh');
    final header = rows.first.map((e) => e.toString().trim()).toList();

    final required = [
      'supplier',
      'category',
      'name',
      'sale_price_usd',
      'is_active',
    ];
    for (final col in required) {
      if (!header.contains(col)) {
        throw StateError("CSV sarlavhasida '$col' ustuni yo‘q");
      }
    }

    int idx(String col) => header.indexOf(col);
    String get(List row, String col) {
      final j = idx(col);
      if (j < 0 || j >= row.length) return '';
      return (row[j] ?? '').toString().trim();
    }

    final items = <_ImportRow>[];
    for (var i = 1; i < rows.length; i++) {
      final r = rows[i];
      if (r.isEmpty || r.every((e) => (e?.toString().trim() ?? '').isEmpty)) {
        continue;
      }
      items.add(_ImportRow(
        line: i + 1,
        supplier: get(r, 'supplier'),
        category: get(r, 'category'),
        name: get(r, 'name'),
        barcode: get(r, 'barcode'),
        type: get(r, 'type'),
        size: get(r, 'size'),
        color: get(r, 'color'),
        qtyOk: get(r, 'qty_ok'),
        qtyDefect: get(r, 'qty_defect'),
        costPriceUsd: get(r, 'cost_price_usd'),
        salePriceUsd: get(r, 'sale_price_usd'),
        amountUsd: get(r, 'amount_usd'),
        isActive: get(r, 'is_active'),
      ));
    }
    return _ParsedProductsSheet(rows: items);
  }

  Future<_ParsedProductsSheet> _parseXlsx({required File file}) async {
    final bytes = await file.readAsBytes();
    final excel = xlsx.Excel.decodeBytes(bytes);
    final table =
        excel.tables.values.isNotEmpty ? excel.tables.values.first : null;
    if (table == null || table.rows.isEmpty) {
      throw StateError('Excel bo‘sh');
    }

    final header = table.rows.first
        .map((c) => (c?.value?.toString() ?? '').trim())
        .toList();

    final required = [
      'supplier',
      'category',
      'name',
      'sale_price_usd',
      'is_active',
    ];
    for (final col in required) {
      if (!header.contains(col)) {
        throw StateError("Excel sarlavhasida '$col' ustuni yo‘q");
      }
    }

    int idx(String col) => header.indexOf(col);
    String get(List<xlsx.Data?> row, String col) {
      final j = idx(col);
      if (j < 0 || j >= row.length) return '';
      final v = row[j]?.value;
      return (v ?? '').toString().trim();
    }

    final items = <_ImportRow>[];
    for (var i = 1; i < table.rows.length; i++) {
      final r = table.rows[i];
      if (r.isEmpty ||
          r.every((c) => ((c?.value?.toString() ?? '').trim()).isEmpty)) {
        continue;
      }
      items.add(_ImportRow(
        line: i + 1,
        supplier: get(r, 'supplier'),
        category: get(r, 'category'),
        name: get(r, 'name'),
        barcode: get(r, 'barcode'),
        type: get(r, 'type'),
        size: get(r, 'size'),
        color: get(r, 'color'),
        qtyOk: get(r, 'qty_ok'),
        qtyDefect: get(r, 'qty_defect'),
        costPriceUsd: get(r, 'cost_price_usd'),
        salePriceUsd: get(r, 'sale_price_usd'),
        amountUsd: get(r, 'amount_usd'),
        isActive: get(r, 'is_active'),
      ));
    }
    return _ParsedProductsSheet(rows: items);
  }

  // -------------------- Upsert helpers --------------------------------------

  Future<Map<String, dynamic>?> _findProductByBarcode(String barcode) async {
    if (barcode.isEmpty) {
      return null;
    }
    final filter = "barcode='$barcode'";
    final res = await ApiService.get(
      'collections/products/records?perPage=1&page=1&filter=${Uri.encodeComponent(filter)}',
      token: token,
    );
    final items =
        List<Map<String, dynamic>>.from((res['items'] as List?) ?? []);
    if (items.isEmpty) {
      return null;
    }
    return items.first;
  }

  Future<Map<String, dynamic>?> _findProductByName(String name) async {
    if (name.isEmpty) {
      return null;
    }
    final safe = name.replaceAll("'", r"\'");
    final filter = "name='$safe'";
    final res = await ApiService.get(
      'collections/products/records?perPage=1&page=1&filter=${Uri.encodeComponent(filter)}',
      token: token,
    );
    final items =
        List<Map<String, dynamic>>.from((res['items'] as List?) ?? []);
    if (items.isEmpty) return null;
    return items.first;
  }

  double? _toDouble(String s) {
    if (s.isEmpty) return null;
    return double.tryParse(s.replaceAll(',', '.'));
  }

  bool _toBool(String s) {
    final t = s.trim().toLowerCase();
    return t == '1' || t == 'true' || t == 'ha' || t == 'yes';
  }

  // -------------------- Import (upsert) -------------------------------------

  Future<ImportResult> importProducts(_ParsedProductsSheet parsed) async {
    final errors = <String>[];
    final createdIds = <String>[];
    int updated = 0;

    // nom→id kesh
    final catMap = await _buildNameToIdAny(ProductFields.categoryCollections);
    final supMap = await _buildNameToIdAny(ProductFields.supplierCollections);

    // qaysi kolleksiyada kategoriya yaratamiz (prefer)
    final categoryCollectionPrefer = ProductFields.categoryCollections.first;
    final supplierCollectionPrefer = ProductFields.supplierCollections.first;

    for (final row in parsed.rows) {
      try {
        // majburiy tekshiruvlar
        if (row.name.isEmpty) throw StateError('name bo‘sh');
        if (row.category.isEmpty) throw StateError('category bo‘sh');
        if (row.supplier.isEmpty) throw StateError('supplier bo‘sh');
        final price = _toDouble(row.salePriceUsd);
        if (price == null) {
          throw StateError("sale_price_usd noto‘g‘ri: ${row.salePriceUsd}");
        }
        final isActive = _toBool(row.isActive);

        // ref id'lar
        final categoryId = await _ensureRefId(
          collection: categoryCollectionPrefer,
          name: row.category,
          cache: catMap,
        );
        final supplierId = await _ensureRefId(
          collection: supplierCollectionPrefer,
          name: row.supplier,
          cache: supMap,
        );

        // upsert target
        Map<String, dynamic>? existing;
        if (row.barcode.isNotEmpty) {
          existing = await _findProductByBarcode(row.barcode);
        }
        existing ??= await _findProductByName(row.name);

        final body = <String, dynamic>{
          ProductFields.name: row.name,
          ProductFields.category: categoryId,
          ProductFields.supplier: supplierId,
          ProductFields.priceUsd: price, // sale_price_usd
          ProductFields.isActive: isActive,
        };

        // optionallar
        if (row.barcode.isNotEmpty) body[ProductFields.barcode] = row.barcode;
        if (row.type.isNotEmpty) body[ProductFields.type] = row.type;
        if (row.size.isNotEmpty) body[ProductFields.size] = row.size;
        if (row.color.isNotEmpty) body[ProductFields.color] = row.color;

        final cost = _toDouble(row.costPriceUsd);
        if (cost != null) body[ProductFields.costPriceUsd] = cost;

        final qtyOk = _toDouble(row.qtyOk);
        if (qtyOk != null) body[ProductFields.stockOk] = qtyOk;

        final qtyDef = _toDouble(row.qtyDefect);
        if (qtyDef != null) body[ProductFields.stockDefect] = qtyDef;

        // amount_usd → avg_cost_usd (agar util. ma'noda o‘rtacha qiymat bo‘lsa)
        final amt = _toDouble(row.amountUsd);
        if (amt != null) body[ProductFields.avgCostUsd] = amt;

        if (existing == null) {
          // CREATE
          final res = await ApiService.post(
              'collections/products/records', body,
              token: token);
          createdIds.add(res['id'] as String);
        } else {
          // PATCH
          final id = (existing['id'] as String);
          await ApiService.patch('collections/products/records/$id', body,
              token: token);
          updated++;
        }
      } catch (e) {
        errors.add('Line ${row.line}: $e');
      }
    }

    return ImportResult(
        createdIds: createdIds, updatedCount: updated, errors: errors);
  }
}

// ============================ Internal models ===============================

class _ParsedProductsSheet {
  final List<_ImportRow> rows;
  _ParsedProductsSheet({required this.rows});
}

class _ImportRow {
  final int line;
  final String supplier;
  final String category;
  final String name;
  final String barcode;
  final String type;
  final String size;
  final String color;
  final String qtyOk;
  final String qtyDefect;
  final String costPriceUsd;
  final String salePriceUsd;
  final String amountUsd;
  final String isActive;
  _ImportRow({
    required this.line,
    required this.supplier,
    required this.category,
    required this.name,
    required this.barcode,
    required this.type,
    required this.size,
    required this.color,
    required this.qtyOk,
    required this.qtyDefect,
    required this.costPriceUsd,
    required this.salePriceUsd,
    required this.amountUsd,
    required this.isActive,
  });
}

class ImportResult {
  final List<String> createdIds;
  final int updatedCount;
  final List<String> errors;
  bool get hasErrors => errors.isNotEmpty;
  ImportResult(
      {required this.createdIds,
      required this.updatedCount,
      required this.errors});
}
