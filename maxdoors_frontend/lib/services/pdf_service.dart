import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/order.dart';

class PdfService {
  static pw.Font? _base;
  static pw.Font? _bold;

  static Future<void> _ensureFonts() async {
    if (_base != null && _bold != null) return;

    Future<pw.Font> _load(String path) async {
      final data = await rootBundle.load(path);
      if (data.lengthInBytes == 0) {
        throw StateError('Font asset is empty: $path');
      }
      return pw.Font.ttf(data);
    }

    // Faqat assetlardan yuklaymiz (NotoSans)
    _base = await _load('assets/fonts/NotoSans-Regular.ttf');
    _bold = await _load('assets/fonts/NotoSans-Bold.ttf');
  }

  static Future<Uint8List> buildPackingSlip({
    required Order order,
    required List<OrderItem> items,
    String companyName = 'MaxDoors',
  }) async {
    await _ensureFonts();

    // pdf 3.11.* da fallback parametri yo‘q, shuning uchun withFont kifoya
    final theme = pw.ThemeData.withFont(
      base: _base!,
      bold: _bold!,
      italic: _base!,
      boldItalic: _bold!,
    );

    final doc = pw.Document(theme: theme);
    final now = DateTime.now();
    final dfDate = DateFormat('yyyy-MM-dd HH:mm');

    final dealerName = order.dealerLabel;
    final regionName = order.regionLabel;
    final managerName = order.managerLabel;
    final warehouseName = order.warehouseLabel;
    final orderNo = order.numberOrId;

    // Summalar
    double subtotal = 0;
    for (final it in items) {
      subtotal += (it.unitPriceUsd ?? 0) * (it.qty ?? 0);
    }
    final discountType = order.discountType ?? 'none';
    final discountValue = order.discountValue ?? 0;
    final discountUsd = discountType == 'percent'
        ? (subtotal * discountValue) / 100.0
        : (discountType == 'amount' ? discountValue : 0.0);
    final total = (subtotal - discountUsd).clamp(0, double.infinity);

    pw.Widget header() => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(companyName,
                    style: pw.TextStyle(
                        fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text('Packing slip / Pick list'),
                pw.Text('Order: $orderNo'),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Date: ${dfDate.format(now)}'),
                pw.Text('Status: ${order.status ?? "-"}'),
              ],
            ),
          ],
        );

    pw.Widget meta() => pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Dealer: $dealerName'),
                  pw.Text('Region: $regionName'),
                  pw.Text('Warehouse: $warehouseName'),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Manager: $managerName'),
                  if (order.note?.isNotEmpty == true)
                    pw.Text('Note: ${order.note}'),
                ],
              ),
            ],
          ),
        );

    pw.Widget itemsTable() {
      final headers = ['#', 'Product', 'Qty', 'Unit (USD)', 'Amount'];
      final data = <List<String>>[];
      var i = 0;
      for (final it in items) {
        i++;
        final name = it.expandProductName ?? it.productId ?? '-';
        final qty = it.qty ?? 0;
        final price = it.unitPriceUsd ?? 0;
        final amt = qty * price;
        data.add([
          i.toString(),
          name,
          qty.toString(),
          price.toStringAsFixed(2),
          amt.toStringAsFixed(2)
        ]);
      }
      return pw.Table.fromTextArray(
        headers: headers,
        data: data,
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        border: null,
        cellAlignments: const {
          0: pw.Alignment.centerRight,
          1: pw.Alignment.centerLeft,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
          4: pw.Alignment.centerRight,
        },
        headerPadding: const pw.EdgeInsets.all(8),
        cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      );
    }

    pw.Widget totals() => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _row('Subtotal:', '\$${subtotal.toStringAsFixed(2)}'),
              _row(
                'Discount:',
                '- \$${discountUsd.toStringAsFixed(2)}'
                    '${discountType == "percent" ? " (${discountValue.toStringAsFixed(2)}%)" : ""}',
              ),
              pw.SizedBox(height: 4),
              _rowBold('TOTAL:', '\$${total.toStringAsFixed(2)}'),
            ],
          ),
        );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          header(),
          pw.SizedBox(height: 12),
          meta(),
          pw.SizedBox(height: 16),
          itemsTable(),
          pw.SizedBox(height: 12),
          totals(),
          pw.SizedBox(height: 24),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Prepared: $warehouseName'),
                  pw.Text('Signature: ____________'),
                ],
              ),
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: orderNo, // QR ichida humanId/number
                width: 80,
                height: 80,
              ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _row(String l, String r) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text(l), pw.Text(r)],
      );

  static pw.Widget _rowBold(String l, String r) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(l, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(r, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      );
}
