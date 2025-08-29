import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/async_dropdown.dart';

class DealerEditScreen extends StatefulWidget {
  final Map<String, dynamic>? dealer; // null -> create
  const DealerEditScreen({super.key, this.dealer});

  @override
  State<DealerEditScreen> createState() => _DealerEditScreenState();
}

class _DealerEditScreenState extends State<DealerEditScreen> {
  final nameCtrl = TextEditingController();
  final tinCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  String? regionId; // dropdown qiymati
  String? assignedManagerId; // dropdown qiymati
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.dealer;
    if (d != null) {
      nameCtrl.text = d['name'] ?? '';
      tinCtrl.text = d['tin'] ?? '';
      noteCtrl.text = d['note'] ?? '';
      regionId = d['region'];
      assignedManagerId = d['assigned_manager'];
    }
  }

  Future<List<Map<String, String>>> _fetchRegions() async {
    final auth = context.read<AuthProvider>();
    final res = await ApiService.get(
        'collections/regions/records?perPage=200&sort=name',
        token: auth.token);
    final items = List<Map<String, dynamic>>.from(res['items'] as List);
    return items
        .map((e) => {
              'id': e['id'] as String,
              'label': (e['name'] ?? e['id']).toString(),
            })
        .toList();
  }

  Future<List<Map<String, String>>> _fetchManagers() async {
    final auth = context.read<AuthProvider>();
    // faqat admin/accountant ko‘rsatadi (manager tahrir qila olmaydi, lekin ro‘yxat ham kerakmas)
    if (auth.role != 'admin' && auth.role != 'accountant') {
      return [];
    }
    final res = await ApiService.get(
        "collections/users/records?filter=role='manager'&perPage=200&sort=email",
        token: auth.token);
    final items = List<Map<String, dynamic>>.from(res['items'] as List);
    return items
        .map((e) => {
              'id': e['id'] as String,
              'label': (e['email'] ?? e['id']).toString(),
            })
        .toList();
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
      final role = context.read<AuthProvider>().role;

      final body = {
        'name': nameCtrl.text.trim(),
        'tin': tinCtrl.text.trim().isEmpty ? null : tinCtrl.text.trim(),
        'note': noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
        'region': regionId,
        'assigned_manager': (role == 'admin' || role == 'accountant')
            ? assignedManagerId
            : null,
      };

      if (widget.dealer == null) {
        await ApiService.post('collections/dealers/records', body,
            token: token);
      } else {
        await ApiService.patch(
            'collections/dealers/records/${widget.dealer!['id']}', body,
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
    final role = context.read<AuthProvider>().role;
    final readOnlyForManager = role == 'manager'; // menejer CRUD qila olmaydi

    return Scaffold(
      appBar: AppBar(
          title: Text(
              widget.dealer == null ? 'Diller yaratish' : 'Diller tahrirlash')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
                controller: nameCtrl,
                readOnly: readOnlyForManager,
                decoration: const InputDecoration(labelText: 'Nomi')),
            TextField(
                controller: tinCtrl,
                readOnly: readOnlyForManager,
                decoration: const InputDecoration(labelText: 'TIN')),
            const SizedBox(height: 8),

            // Region dropdown (hamma rollar ko‘rishi mumkin)
            AsyncDropdown(
              label: 'Region',
              value: regionId,
              enabled: !readOnlyForManager,
              fetchOptions: _fetchRegions,
              onChanged: (v) => setState(() => regionId = v),
            ),
            const SizedBox(height: 8),

            // Manager dropdown (faqat admin/accountant uchun aktiv)
            AsyncDropdown(
              label: 'Assigned manager',
              value: assignedManagerId,
              enabled: role == 'admin' || role == 'accountant',
              fetchOptions: _fetchManagers,
              onChanged: (v) => setState(() => assignedManagerId = v),
            ),

            const SizedBox(height: 8),
            TextField(
                controller: noteCtrl,
                readOnly: readOnlyForManager,
                decoration: const InputDecoration(labelText: 'Izoh')),
            const SizedBox(height: 16),

            if (!readOnlyForManager)
              ElevatedButton(
                onPressed: saving ? null : _save,
                child: Text(saving ? 'Saqlanmoqda...' : 'Saqlash'),
              )
            else
              const Text('Menejer faqat ko‘ra oladi (CRUD yo‘q).',
                  style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
