import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';

import '../services/api_service.dart';

/// CSV sarlavhasi:
/// product_name, barcode, qty, price_usd, mode, note
///  - mode: 'delta' (default) yoki 'set'
///  - qty: butun/haqiqiy son. Manfiy ham bo‘lishi mumkin (delta uchun)
///
/// Kolleksiya nomlari moslashtirish
class StockFields {
  static const String products = 'products';
  static const String stockLogs =
      'stock_logs'; // sizdagi nom boshqacha bo‘lsa moslang

  // product fields
  static const String productName = 'name';
  static const String productBarcode = 'barcode';
  static const String productPriceUsd = 'price_usd';

  // stock_log fields
  static const String slProduct = 'product'; // relation
  static const String slQty = 'qty'; // + kirim, - chiqim
  static const String slType = 'type'; // 'manual_import'
  static const String slNote = 'note';
  static const String slIsDefect =
      'is_defect'; // agar sizda shunday maydon bo‘lsa (ixtiyoriy)
}

class ProductStockImportService {
  final String token;
  ProductStockImportService({required this.token});

  // ---- CSV parse ----
  Future<_StockParsedCsv> parseCsv({List<int>? bytes, File? file}) async {
    final content = bytes != null
        ? utf8.decode(bytes)
        : await file!.readAsString(encoding: const Utf8Codec());
    final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
        .convert(content);
    if (rows.isEmpty) {
      throw StateError('CSV bo‘sh');
    }
    final header =
        rows.first.map((e) => e.toString().trim().toLowerCase()).toList();

    // minimal tekshiruv
    if (!header.contains('product_name') && !header.contains('barcode')) {
      throw StateError(
          "CSV sarlavhasida kamida 'product_name' yoki 'barcode' bo‘lishi kerak");
    }

    int idx(String col) => header.indexOf(col);

    final List<_StockRow> items = [];
    for (int i = 1; i < rows.length; i++) {
      final r = rows[i];
      if (r.isEmpty || r.every((e) => (e?.toString().trim() ?? '').isEmpty))
        continue;

      String getS(String col) {
        final j = idx(col);
        if (j < 0 || j >= r.length) return '';
        return (r[j] ?? '').toString().trim();
      }

      items.add(_StockRow(
        line: i + 1,
        productName: getS('product_name'),
        barcode: getS('barcode'),
        qtyStr: getS('qty'),
        priceStr: getS('price_usd'),
        mode: (getS('mode').isEmpty ? 'delta' : getS('mode')).toLowerCase(),
        note: getS('note'),
      ));
    }
    return _StockParsedCsv(header: header, rows: items);
  }

  // ---- Helpers: fetch product maps ----
  Future<List<Map<String, dynamic>>> _fetchAll(String collection,
      {String? filter, String? fields, int perPage = 200}) async {
    final all = <Map<String, dynamic>>[];
    int page = 1;
    while (true) {
      final qp = StringBuffer('perPage=$perPage&page=$page');
      if (filter != null && filter.isNotEmpty)
        qp.write('&filter=${Uri.encodeComponent(filter)}');
      if (fields != null && fields.isNotEmpty)
        qp.write('&fields=$fields'); // PB >=0.22
      final res = await ApiService.get('collections/$collection/records?$qp',
          token: token);
      final items = List<Map<String, dynamic>>.from(res['items'] as List);
      all.addAll(items);
      final total = (res['totalItems'] as num?)?.toInt() ?? all.length;
      if (all.length >= total || items.isEmpty) break;
      page++;
    }
    return all;
  }

  Future<Map<String, Map<String, dynamic>>> _mapProductsByName(
      Iterable<String> lowerNames) async {
    if (lowerNames.isEmpty) return {};
    final all = await _fetchAll(
        StockFields.products); // kerak bo'lsa filterlab chaqirishingiz mumkin
    final map = <String, Map<String, dynamic>>{};
    for (final p in all) {
      final n =
          (p[StockFields.productName] ?? '').toString().trim().toLowerCase();
      if (n.isNotEmpty) map[n] = p;
    }
    return map;
  }

  Future<Map<String, Map<String, dynamic>>> _mapProductsByBarcode(
      Iterable<String> barcodes) async {
    if (barcodes.isEmpty) return {};
    final all = await _fetchAll(StockFields.products);
    final map = <String, Map<String, dynamic>>{};
    for (final p in all) {
      final b = (p[StockFields.productBarcode] ?? '').toString().trim();
      if (b.isNotEmpty) map[b] = p;
    }
    return map;
  }

  // ---- Current stock (sum of stock_logs.qty) ----
  Future<double> _getCurrentStock(String productId) async {
    // PB aggregatsiya yo‘qligi uchun summani klientda hisoblaymiz
    final items = await _fetchAll(
      StockFields.stockLogs,
      filter: "${StockFields.slProduct}='$productId'",
      perPage: 200,
    );
    double sum = 0;
    for (final it in items) {
      final q = it[StockFields.slQty];
      if (q is num)
        sum += q.toDouble();
      else if (q != null) sum += double.tryParse(q.toString()) ?? 0;
    }
    return sum;
  }

  // ---- Import main ----
  Future<StockImportResult> importStockAndPrices(_StockParsedCsv parsed) async {
    final errors = <String>[];
    int pricePatched = 0;
    int stockLogged = 0;

    // Build lookup maps
    final names = parsed.rows
        .map((r) => r.productName.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    final barcodes = parsed.rows
        .map((r) => r.barcode.trim())
        .where((e) => e.isNotEmpty)
        .toSet();

    final byName = await _mapProductsByName(names);
    final byBarcode = await _mapProductsByBarcode(barcodes);

    for (final row in parsed.rows) {
      try {
        // Resolve product
        Map<String, dynamic>? product;
        if (row.barcode.isNotEmpty) {
          product = byBarcode[row.barcode];
        }
        product ??= byName[row.productName.toLowerCase()];
        if (product == null) {
          throw StateError(
              "Mahsulot topilmadi: '${row.productName}' / '${row.barcode}'");
        }
        final productId = product['id'] as String;

        // 1) Price patch (ixtiyoriy)
        final newPrice = row.priceUsd;
        if (newPrice != null) {
          await ApiService.patch(
            'collections/${StockFields.products}/records/$productId',
            {StockFields.productPriceUsd: newPrice},
            token: token,
          );
          pricePatched++;
        }

        // 2) Stock update (ixtiyoriy)
        if (row.qty != null) {
          double delta = row.qty!;
          if (row.mode == 'set') {
            final current = await _getCurrentStock(productId);
            delta = row.qty! - current;
            // delta 0 bo‘lsa log yozmaymiz
            if (delta.abs() < 1e-9) {
              continue;
            }
          }
          final logBody = <String, dynamic>{
            StockFields.slProduct: productId,
            StockFields.slQty: delta,
            StockFields.slType: 'manual_import',
            StockFields.slNote:
                row.note?.isNotEmpty == true ? row.note : 'CSV import',
            // Agar sizda defekt maydoni bo'lsa va kerak bo'lsa:
            // StockFields.slIsDefect: false,
          };
          await ApiService.post(
              'collections/${StockFields.stockLogs}/records', logBody,
              token: token);
          stockLogged++;
        }
      } catch (e) {
        errors.add('Line ${row.line}: $e');
      }
    }

    return StockImportResult(
        pricePatched: pricePatched, stockLogged: stockLogged, errors: errors);
  }
}

// --------- Internal models ---------
class _StockParsedCsv {
  final List<String> header;
  final List<_StockRow> rows;
  _StockParsedCsv({required this.header, required this.rows});
}

class _StockRow {
  final int line;
  final String productName;
  final String barcode;
  final String qtyStr;
  final String priceStr;
  final String mode;
  final String? note;

  _StockRow({
    required this.line,
    required this.productName,
    required this.barcode,
    required this.qtyStr,
    required this.priceStr,
    required this.mode,
    required this.note,
  });

  double? get qty {
    if (qtyStr.isEmpty) return null;
    return double.tryParse(qtyStr.replaceAll(',', '.'));
  }

  double? get priceUsd {
    if (priceStr.isEmpty) return null;
    return double.tryParse(priceStr.replaceAll(',', '.'));
  }
}

class StockImportResult {
  final int pricePatched;
  final int stockLogged;
  final List<String> errors;
  bool get hasErrors => errors.isNotEmpty;
  StockImportResult({
    required this.pricePatched,
    required this.stockLogged,
    required this.errors,
  });
}
