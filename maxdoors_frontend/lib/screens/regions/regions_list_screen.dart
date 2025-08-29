import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'region_edit_screen.dart';
import '../../widgets/loading.dart';

class RegionsListScreen extends StatefulWidget {
  const RegionsListScreen({super.key});

  @override
  State<RegionsListScreen> createState() => _RegionsListScreenState();
}

class _RegionsListScreenState extends State<RegionsListScreen> {
  bool _loading = true;
  String _error = '';
  List<Map<String, dynamic>> _items = [];

  bool get _canEdit {
    final role = context.read<AuthProvider>().role;
    return role == 'admin' || role == 'accountant';
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final auth = context.read<AuthProvider>();
      final token = auth.token!;
      String path = 'collections/regions/records?perPage=100&sort=name';

      // Manager faqat o'ziga tegishli regionlarni ko'radi (agar sizda shunday bog'lanish bo'lsa).
      // Agar regionlarda "managers" kabi relation bo'lmasa, buni o‘tkazib yuboring.
      if (auth.role == 'manager') {
        // misol uchun: regions kolleksiyasida managers (rel list) maydoni bo'lsa:
        // path += "&filter=managers~'${auth.userId}'";
        // Agar hozircha bog'lanish yo'q bo'lsa, umumiy ro'yxatni ko'rsatib turamiz yoki backend rules bilan cheklaysiz.
      }

      final res = await ApiService.get(path, token: token);
      _items = List<Map<String, dynamic>>.from(res['items'] as List);
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('O‘chirish?'),
        content: const Text('Bu regionni o‘chirmoqchimisiz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(_, false),
              child: const Text('Yo‘q')),
          ElevatedButton(
              onPressed: () => Navigator.pop(_, true), child: const Text('Ha')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final token = context.read<AuthProvider>().token!;
      await ApiService.delete('collections/regions/records/$id', token: token);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('O‘chirildi')));
      }
      await _fetch();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Xato: $e')));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Regionlar'),
        actions: [
          IconButton(onPressed: _fetch, icon: const Icon(Icons.refresh)),
          if (_canEdit)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const RegionEditScreen()));
                if (mounted) _fetch();
              },
            ),
        ],
      ),
      body: _loading
          ? const Loading(text: 'Yuklanmoqda...')
          : _error.isNotEmpty
              ? Center(child: Text('Xato: $_error'))
              : _items.isEmpty
                  ? const Center(child: Text('Region yo‘q'))
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final r = _items[i];
                        return ListTile(
                          title: Text(r['name'] ?? r['id']),
                          subtitle: Text(r['id']),
                          onTap: _canEdit
                              ? () async {
                                  await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              RegionEditScreen(region: r)));
                                  if (mounted) _fetch();
                                }
                              : null,
                          trailing: _canEdit
                              ? IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => _delete(r['id']))
                              : null,
                        );
                      },
                    ),
    );
  }
}
