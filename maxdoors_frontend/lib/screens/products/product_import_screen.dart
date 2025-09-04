import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/product_import_service.dart';

class ProductImportScreen extends StatefulWidget {
  const ProductImportScreen({super.key});

  @override
  State<ProductImportScreen> createState() => _ProductImportScreenState();
}

class _ProductImportScreenState extends State<ProductImportScreen> {
  File? _file;
  String? _status;
  bool _creatingMissing = false;
  bool _busy = false;
  List<String> _errors = [];
  int _created = 0;
  int _updated = 0;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
      withData: false,
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _file = File(result.files.single.path!);
        _status =
            'Fayl tanlandi: ${_file!.path.split(Platform.pathSeparator).last}';
        _errors = [];
        _created = 0;
        _updated = 0;
      });
    }
  }

  Future<void> _downloadTemplate() async {
    try {
      final f = await ProductImportService.writeTemplate();
      if (!mounted) return;
      setState(() {
        _status = 'Shablon saqlandi: ${f.path}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Shablon: ${f.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xato: $e')),
      );
    }
  }

  Future<void> _dryRun() async {
    if (_file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avval CSV yoki XLSX fayl tanlang')));
      return;
    }
    final token = context.read<AuthProvider>().token!;
    final service =
        ProductImportService(token: token, createMissingRefs: _creatingMissing);

    setState(() {
      _busy = true;
      _errors = [];
      _created = 0;
      _updated = 0;
      _status = 'Tekshirilmoqda...';
    });
    try {
      final parsed = await service.parseCsvOrXlsx(file: _file);
      setState(() {
        _status = 'Dry-run OK. ${parsed.rows.length} qator topildi.';
      });
    } catch (e) {
      setState(() {
        _status = 'Dry-run xato';
        _errors = ['Dry-run: $e'];
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _doImport() async {
    if (_file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avval CSV yoki XLSX fayl tanlang')));
      return;
    }
    final token = context.read<AuthProvider>().token!;
    final service =
        ProductImportService(token: token, createMissingRefs: _creatingMissing);

    setState(() {
      _busy = true;
      _errors = [];
      _created = 0;
      _updated = 0;
      _status = 'Import boshlanmoqda...';
    });
    try {
      final parsed = await service.parseCsvOrXlsx(file: _file);
      final res = await service.importProducts(parsed);
      setState(() {
        _created = res.createdIds.length;
        _updated = res.updatedCount;
        _errors = res.errors;
        _status =
            'Import yakunlandi. Yaratilgan: ${res.createdIds.length}, yangilangan: ${res.updatedCount}, xatolar: ${res.errors.length}';
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
    final canImport = role == 'admin' || role == 'accountant';

    return Scaffold(
      appBar: AppBar(title: const Text('Mahsulot importi (CSV/XLSX)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: canImport
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'Ustunlar: supplier, category, name, barcode, type, size, color, qty_ok, qty_defect, cost_price_usd, sale_price_usd, amount_usd, is_active'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _busy ? null : _downloadTemplate,
                        icon: const Icon(Icons.download),
                        label: const Text('Shablon yuklab olish (.xlsx)'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _busy ? null : _pickFile,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('CSV/XLSX tanlash'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Switch(
                        value: _creatingMissing,
                        onChanged: _busy
                            ? null
                            : (v) => setState(() => _creatingMissing = v),
                      ),
                      const Text(
                          'Mavjud bo‘lmasa kategoriya/supplierni yaratish'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: _busy ? null : _dryRun,
                        child: const Text('Dry-run (faqat tekshir)'),
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
                  if (_created > 0 || _updated > 0)
                    Text('Yaratildi: $_created   •   Yangilandi: $_updated'),
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
            : const Center(child: Text('Sizda import qilish huquqi yo‘q')),
      ),
    );
  }
}
