import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'user_edit_screen.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  bool _loading = true;
  String _error = '';
  List<Map<String, dynamic>> _items = [];
  String _query = '';
  int _page = 1;
  int _perPage = 50;
  int _total = 0;

  final _searchCtrl = TextEditingController();

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final token = context.read<AuthProvider>().token!;
      final filter = _query.isEmpty ? '' : "email~'$_query' || name~'$_query'";
      final uri = StringBuffer(
          'collections/users/records?perPage=$_perPage&page=$_page&sort=-created');
      if (filter.isNotEmpty) {
        uri.write('&filter=${Uri.encodeComponent(filter)}');
      }
      // Agar faqat ayrim maydonlarni istasangiz, PB >= 0.22 da fields= ni ishlatish mumkin
      final res = await ApiService.get(uri.toString(), token: token);
      final items = List<Map<String, dynamic>>.from(res['items'] as List);
      setState(() {
        _items = items;
        _total = (res['totalItems'] as num?)?.toInt() ?? items.length;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('O‘chirish?'),
        content: const Text('Foydalanuvchini haqiqatan o‘chirmoqchimisiz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(_, false),
              child: const Text('Bekor qilish')),
          ElevatedButton(
              onPressed: () => Navigator.pop(_, true),
              child: const Text('O‘chirish')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final token = context.read<AuthProvider>().token!;
      await ApiService.delete('collections/users/records/$id', token: token);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('O‘chirildi')));
        _fetch();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Xato: $e')));
    }
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().role ?? '';
    final isAdmin = role == 'admin';
    if (!isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Sizda bu bo‘limni ko‘rish huquqi yo‘q')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Foydalanuvchilar'),
        actions: [
          IconButton(
            tooltip: 'Yangilash',
            icon: const Icon(Icons.refresh),
            onPressed: _fetch,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => const UserEditScreen(),
            ),
          );
          if (created == true) _fetch();
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Yaratish'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Email yoki Name bo‘yicha qidirish',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (v) {
                      _query = v.trim();
                      _page = 1;
                      _fetch();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _query = _searchCtrl.text.trim();
                    _page = 1;
                    _fetch();
                  },
                  child: const Text('Qidirish'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading) const LinearProgressIndicator(),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('Xato: $_error',
                    style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: _items.isEmpty
                  ? const Center(child: Text('Ma’lumot yo‘q'))
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final u = _items[i];
                        final id = u['id'] as String;
                        final email = (u['email'] ?? '').toString();
                        final name = (u['name'] ?? '').toString();
                        final role = (u['role'] ?? '')
                            .toString(); // siz user kolleksiyasida role saqlaysiz
                        final active = (u['active'] ??
                                u['is_active'] ??
                                u['verified'] ??
                                false) ==
                            true;

                        return ListTile(
                          leading: CircleAvatar(
                              child: Text(email.isNotEmpty
                                  ? email[0].toUpperCase()
                                  : '?')),
                          title: Text(email),
                          subtitle: Text(
                              '${name.isEmpty ? '-' : name}  •  role: ${role.isEmpty ? '-' : role}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(active ? Icons.check_circle : Icons.block,
                                  color: active ? Colors.green : Colors.red,
                                  size: 20),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () async {
                                  final updated = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => UserEditScreen(
                                          userId: id, initial: u),
                                    ),
                                  );
                                  if (updated == true) _fetch();
                                },
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _delete(id),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            if (_total > _perPage)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _page > 1
                        ? () {
                            setState(() => _page--);
                            _fetch();
                          }
                        : null,
                    child: const Text('Oldingi'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('$_page'),
                  ),
                  TextButton(
                    onPressed: (_page * _perPage) < _total
                        ? () {
                            setState(() => _page++);
                            _fetch();
                          }
                        : null,
                    child: const Text('Keyingi'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
