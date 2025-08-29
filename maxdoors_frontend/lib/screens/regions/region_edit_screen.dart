import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class RegionEditScreen extends StatefulWidget {
  final Map<String, dynamic>? region; // null -> create, not null -> edit
  const RegionEditScreen({super.key, this.region});

  @override
  State<RegionEditScreen> createState() => _RegionEditScreenState();
}

class _RegionEditScreenState extends State<RegionEditScreen> {
  final nameCtrl = TextEditingController();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.region != null) {
      nameCtrl.text = widget.region!['name'] ?? '';
    }
  }

  Future<void> _save() async {
    if (nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nomi majburiy')));
      return;
    }
    setState(() => saving = true);
    try {
      final token = context.read<AuthProvider>().token!;
      final body = {'name': nameCtrl.text.trim()};

      if (widget.region == null) {
        await ApiService.post('collections/regions/records', body,
            token: token);
      } else {
        await ApiService.patch(
            'collections/regions/records/${widget.region!['id']}', body,
            token: token);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Xato: $e')));
      }
    } finally {
      setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.region != null;
    return Scaffold(
      appBar:
          AppBar(title: Text(isEdit ? 'Region tahrirlash' : 'Region yaratish')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nomi')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: saving ? null : _save,
              child: Text(saving ? 'Saqlanmoqda...' : 'Saqlash'),
            ),
          ],
        ),
      ),
    );
  }
}
