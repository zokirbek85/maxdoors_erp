// lib/services/product_import_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

import '../services/api_service.dart';

/// === Maydon nomlari xaritasi (moslashtiriladigan) ===========================
/// Agar PocketBase'da maydon nomlari boshqacha bo'lsa, faqat shu joyni tahrir qiling.
class ProductFields {
  // Products collection field names
  static const String name = 'name';
  static const String category = 'category'; // rel
  static const String size = 'size';
  static const String priceUsd = 'price_usd'; // double
  static const String unit = 'unit';
  static const String imageUrl = 'image_url'; // yoki `image`
  static const String supplier = 'supplier'; // rel
  static const String barcode = 'barcode'; // ixtiyoriy
  static const String isActive = 'is_active'; // bool, ko'pincha required

  // Reference collections (fallback bilan)
  static const List<String> categoryCollections = [
    'product_categories',
    'categories'
  ];
  static const List<String> supplierCollections = [
    'suppliers'
  ]; // kerak bo'lsa alternativa qo'shing

  // Reference name field
  static const String refNameField = 'name';
}

/// === CSV Format =============================================================
/// name, category_name, size, price_usd, unit, image_url, supplier_name, barcode
class ProductImportService {
  final String token;

  /// Topilmasa kategoriya/supplierni yaratish (true bo'lsa yaratadi)
  final bool createMissingRefs;

  ProductImportService({required this.token, this.createMissingRefs = false});

  /// CSV shablonini foydalanuvchi papkasiga yozadi
  static Future<File> writeTemplate() async {
    final headers = [
      'name',
      'category_name',
      'size',
      'price_usd',
      'unit',
      'image_url',
      'supplier_name',
      'barcode'
    ];
    final example = [
      [
        'Eshik Premium-01',
        'Ichki eshiklar',
        '80x200',
        '120',
        'dona',
        'https://.../img1.jpg',
        'LesKom',
        ''
      ],
      ['Standart', 'Ichki eshiklar', '80x200', '150', 'dona', '', 'LesKom', ''],
    ];
    final dir = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/products_template.csv');
    final csv = const ListToCsvConverter().convert([headers, ...example]);
    await file.writeAsString(csv, encoding: const Utf8Codec());
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
    if (cache.containsKey(key)) return cache[key]!;
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

  // -------------------- CSV parsing ----------------------------------------

  Future<_ParsedCsv> parseCsv({List<int>? bytes, File? file}) async {
    final content = bytes != null
        ? utf8.decode(bytes)
        : await file!.readAsString(encoding: const Utf8Codec());
    final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
        .convert(content);
    if (rows.isEmpty) throw StateError('CSV bo‘sh');
    final header = rows.first.map((e) => e.toString().trim()).toList();

    const requiredCols = [
      'name',
      'category_name',
      'price_usd',
      'unit',
      'supplier_name'
    ];
    for (final col in requiredCols) {
      if (!header.contains(col)) {
        throw StateError("CSV sarlavhasida '$col' ustuni yo‘q");
      }
    }

    int idx(String col) => header.indexOf(col);

    final List<_ProductRow> items = [];
    for (var i = 1; i < rows.length; i++) {
      final r = rows[i];
      if (r.isEmpty || r.every((e) => (e?.toString().trim() ?? '').isEmpty))
        continue;

      String _get(String col) {
        final j = idx(col);
        if (j < 0 || j >= r.length) return '';
        return (r[j] ?? '').toString().trim();
      }

      items.add(_ProductRow(
        line: i + 1,
        name: _get('name'),
        categoryName: _get('category_name'),
        size: _get('size'),
        priceUsd: _get('price_usd'),
        unit: _get('unit'),
        imageUrl: _get('image_url'),
        supplierName: _get('supplier_name'),
        barcode: _get('barcode'),
      ));
    }
    return _ParsedCsv(header: header, rows: items);
  }

  // -------------------- Import main ----------------------------------------

  Future<ImportResult> importProducts(_ParsedCsv parsed) async {
    final errors = <String>[];
    final createdIds = <String>[];

    // Fallback bilan nom->id keshlarini tayyorlaymiz
    final catMap = await _buildNameToIdAny(ProductFields.categoryCollections);
    final supMap = await _buildNameToIdAny(ProductFields.supplierCollections);

    // Yaratish uchun qaysi kolleksiyani ishlatamiz (category uchun)
    final categoryCollectionPrefer = ProductFields.categoryCollections.first;

    for (final row in parsed.rows) {
      try {
        // --- Tekshiruvlar
        if (row.name.isEmpty) throw StateError('name bo‘sh');
        if (row.categoryName.isEmpty) throw StateError('category_name bo‘sh');
        if (row.supplierName.isEmpty) throw StateError('supplier_name bo‘sh');
        final price = double.tryParse(row.priceUsd.replaceAll(',', '.'));
        if (price == null)
          throw StateError('price_usd noto‘g‘ri: ${row.priceUsd}');
        if (row.unit.isEmpty) throw StateError('unit bo‘sh');

        // --- IDlarni yechish
        // Kategoriya: mavjud keshda bo‘lmasa, prefer qilingan kolleksiyada yaratamiz
        final categoryId = await _ensureRefId(
          collection: catMap.isNotEmpty
              ? categoryCollectionPrefer
              : ProductFields.categoryCollections.last,
          name: row.categoryName,
          cache: catMap,
        );
        final supplierId = await _ensureRefId(
          collection: ProductFields.supplierCollections.first,
          name: row.supplierName,
          cache: supMap,
        );

        // --- Product body
        final body = <String, dynamic>{
          ProductFields.name: row.name,
          ProductFields.category: categoryId,
          ProductFields.size: row.size.isEmpty ? null : row.size,
          ProductFields.priceUsd: price,
          ProductFields.unit: row.unit,
          ProductFields.supplier: supplierId,
          // 🔴 MUHIM: majburiy bo‘lsa validationdan o‘tishi uchun default `true`
          ProductFields.isActive: true,
        };
        if (row.barcode.isNotEmpty) body[ProductFields.barcode] = row.barcode;
        if (row.imageUrl.isNotEmpty)
          body[ProductFields.imageUrl] = row.imageUrl;

        final res = await ApiService.post('collections/products/records', body,
            token: token);
        createdIds.add(res['id'] as String);
      } catch (e) {
        errors.add('Line ${row.line}: $e');
      }
    }

    return ImportResult(createdIds: createdIds, errors: errors);
  }
}

// ============================ Internal models ===============================

class _ParsedCsv {
  final List<String> header;
  final List<_ProductRow> rows;
  _ParsedCsv({required this.header, required this.rows});
}

class _ProductRow {
  final int line;
  final String name;
  final String categoryName;
  final String size;
  final String priceUsd;
  final String unit;
  final String imageUrl;
  final String supplierName;
  final String barcode;
  _ProductRow({
    required this.line,
    required this.name,
    required this.categoryName,
    required this.size,
    required this.priceUsd,
    required this.unit,
    required this.imageUrl,
    required this.supplierName,
    required this.barcode,
  });
}

class ImportResult {
  final List<String> createdIds;
  final List<String> errors;
  bool get hasErrors => errors.isNotEmpty;
  ImportResult({required this.createdIds, required this.errors});
}
