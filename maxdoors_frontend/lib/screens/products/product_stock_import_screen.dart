import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/product_stock_import_service.dart';

class ProductStockImportScreen extends StatefulWidget {
  const ProductStockImportScreen({super.key});

  @override
  State<ProductStockImportScreen> createState() =>
      _ProductStockImportScreenState();
}

class _ProductStockImportScreenState extends State<ProductStockImportScreen> {
  File? _file;
  String? _status;
  bool _busy = false;
  int _pricePatched = 0;
  int _stockLogged = 0;
  List<String> _errors = [];

  Future<void> _pickCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: false,
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _file = File(result.files.single.path!);
        _status = 'Fayl: ${_file!.path.split(Platform.pathSeparator).last}';
        _errors = [];
        _pricePatched = 0;
        _stockLogged = 0;
      });
    }
  }

  Future<void> _doImport() async {
    if (_file == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Avval CSV tanlang')));
      return;
    }
    final token = context.read<AuthProvider>().token!;
    final service = ProductStockImportService(token: token);

    setState(() {
      _busy = true;
      _errors = [];
      _pricePatched = 0;
      _stockLogged = 0;
      _status = 'Import boshlanmoqda...';
    });
    try {
      final parsed = await service.parseCsv(file: _file);
      final res = await service.importStockAndPrices(parsed);
      setState(() {
        _pricePatched = res.pricePatched;
        _stockLogged = res.stockLogged;
        _errors = res.errors;
        _status =
            'Yakunlandi. Narx yangilandi: ${res.pricePatched}, Qoldiq yozildi: ${res.stockLogged}, xatolar: ${res.errors.length}';
      });
    } catch (e) {
      setState(() {
        _status = 'Import xato';
        _errors = ['Import: $e'];
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().role ?? '';
    final canImport =
        role == 'admin' || role == 'accountant' || role == 'warehouseman';

    return Scaffold(
      appBar: AppBar(title: const Text('Qoldiq/Narx importi (CSV)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: canImport
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'CSV format: product_name, barcode, qty, price_usd, mode, note'),
                  const SizedBox(height: 6),
                  const Text(
                      '• mode: delta (default) — qty qo‘shimcha/ayirma; set — qty yakuniy qoldiq'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _busy ? null : _pickCsv,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('CSV tanlash'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _busy ? null : _doImport,
                        child: const Text('Import qilish'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_busy) const LinearProgressIndicator(),
                  if (_status != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_status!,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                    ),
                  const SizedBox(height: 8),
                  if (_pricePatched > 0 || _stockLogged > 0)
                    Text(
                        'Narx yangilandi: $_pricePatched   •   Qoldiq yozildi: $_stockLogged'),
                  const SizedBox(height: 8),
                  if (_errors.isNotEmpty)
                    const Text('Xatolar:',
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold)),
                  if (_errors.isNotEmpty)
                    Expanded(
                      child: ListView.builder(
                        itemCount: _errors.length,
                        itemBuilder: (_, i) => Text('• ${_errors[i]}',
                            style: const TextStyle(color: Colors.red)),
                      ),
                    ),
                ],
              )
            : const Center(
                child: Text('Sizda ushbu importni bajarish huquqi yo‘q')),
      ),
    );
  }
}
