import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class DealersListScreen extends StatefulWidget {
  const DealersListScreen({super.key});

  @override
  State<DealersListScreen> createState() => _DealersListScreenState();
}

class _DealersListScreenState extends State<DealersListScreen> {
  bool _loading = true;
  String _error = '';
  List<Map<String, dynamic>> _items = [];
  int _page = 1;
  final int _perPage = 50;
  int _total = 0;

  // dropdown ma'lumotlari
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _managers = [];

  // qidirish
  final _searchCtrl = TextEditingController();
  String _query = '';

  bool get _canEdit {
    final role = context.read<AuthProvider>().role ?? '';
    return role == 'admin' || role == 'accountant';
  }

  Future<void> _fetch({bool resetPage = false}) async {
    if (resetPage) _page = 1;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final token = context.read<AuthProvider>().token!;
      final sb = StringBuffer(
          'collections/dealers/records?perPage=$_perPage&page=$_page&sort=-created');

      if (_query.isNotEmpty) {
        final safe = _query.replaceAll("'", r"\'");
        final filter = "name~'$safe' || code~'$safe' || phone~'$safe'";
        sb.write('&filter=${Uri.encodeComponent(filter)}');
      }

      // expand label’lar uchun
      sb.write('&expand=region,manager');

      final res = await ApiService.get(sb.toString(), token: token);
      final items = List<Map<String, dynamic>>.from(res['items'] as List);
      setState(() {
        _items = items;
        _total = (res['totalItems'] as num?)?.toInt() ?? items.length;
      });

      // dropdownlar (bir marta yoki har fetchda)
      await _ensureDropdowns(token);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _ensureDropdowns(String token) async {
    // Regions
    if (_regions.isEmpty) {
      final r = await ApiService.get(
        'collections/regions/records?perPage=200&sort=name',
        token: token,
      );
      _regions = List<Map<String, dynamic>>.from(r['items'] as List);
    }
    // Managers (users collectiondan role='manager')
    if (_managers.isEmpty) {
      final m = await ApiService.get(
        "collections/users/records?perPage=200&filter=${Uri.encodeComponent("role='manager'")}&sort=name",
        token: token,
      );
      _managers = List<Map<String, dynamic>>.from(m['items'] as List);
    }
  }

  String _expandName(Map<String, dynamic> row, String rel) {
    final exp = row['expand'];
    if (exp is Map && exp[rel] is Map && exp[rel]['name'] != null) {
      return exp[rel]['name'].toString();
    }
    return row[rel]?.toString() ?? '-';
  }

  Future<void> _createOrEditDealer({Map<String, dynamic>? existing}) async {
    if (!_canEdit) return;

    final nameCtrl = TextEditingController(text: existing?['name']?.toString());
    final codeCtrl = TextEditingController(text: existing?['code']?.toString());
    final phoneCtrl =
        TextEditingController(text: existing?['phone']?.toString());
    final addressCtrl =
        TextEditingController(text: existing?['address']?.toString());
    String? regionId = existing?['region']?.toString();
    String? managerId = existing?['manager']?.toString();

    final formKey = GlobalKey<FormState>();
    final isEdit = existing != null;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Dillerni tahrirlash' : 'Yangi diller'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nomi *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Majburiy' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Code',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Telefon',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Region dropdown
                  DropdownButtonFormField<String>(
                    value: regionId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Region *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _regions
                        .map((r) => DropdownMenuItem<String>(
                              value: r['id'].toString(),
                              child: Text(r['name']?.toString() ?? r['id']),
                            ))
                        .toList(),
                    onChanged: (v) => regionId = v,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Region tanlang' : null,
                  ),
                  const SizedBox(height: 8),
                  // Manager dropdown
                  DropdownButtonFormField<String>(
                    value: managerId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Menejer *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _managers
                        .map((m) => DropdownMenuItem<String>(
                              value: m['id'].toString(),
                              child: Text(m['name']?.toString() ??
                                  m['email']?.toString() ??
                                  m['id']),
                            ))
                        .toList(),
                    onChanged: (v) => managerId = v,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Menejer tanlang' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: addressCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Manzil',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              try {
                final token = context.read<AuthProvider>().token!;
                final payload = {
                  'name': nameCtrl.text.trim(),
                  'code': codeCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'address': addressCtrl.text.trim(),
                  'region': regionId,
                  'manager': managerId,
                };

                if (isEdit) {
                  await ApiService.patch(
                    'collections/dealers/records/${existing!['id']}',
                    payload,
                    token: token,
                  );
                } else {
                  await ApiService.post(
                    'collections/dealers/records',
                    payload,
                    token: token,
                  );
                }

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          isEdit ? 'Diller yangilandi' : 'Diller yaratildi'),
                    ),
                  );
                  _fetch(); // ro'yxatni yangilash
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Xato: $e')),
                );
              }
            },
            child: Text(isEdit ? 'Saqlash' : 'Yaratish'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDealer(Map<String, dynamic> row) async {
    if (!_canEdit) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('O‘chirish?'),
        content: Text("“${row['name'] ?? row['id']}” dillerini o‘chirasizmi?"),
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
      await ApiService.delete('collections/dealers/records/${row['id']}',
          token: token);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('O‘chirildi')));
        _fetch();
      }
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
    _fetch(resetPage: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().role ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dillerlar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetch(resetPage: true),
            tooltip: 'Yangilash',
          ),
          if (_canEdit)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _createOrEditDealer(),
              tooltip: 'Yangi diller',
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Qidirish (nom / code / telefon)',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) {
                      _query = _searchCtrl.text.trim();
                      _fetch(resetPage: true);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _query = _searchCtrl.text.trim();
                    _fetch(resetPage: true);
                  },
                  child: const Text('Qidirish'),
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Xato: $_error',
                  style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: _items.isEmpty && !_loading
                ? const Center(child: Text('Dillerlar topilmadi'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final it = _items[i];
                      final name = (it['name'] ?? '').toString();
                      final code = (it['code'] ?? '').toString();
                      final phone = (it['phone'] ?? '').toString();
                      final region = _expandName(it, 'region');
                      final manager = _expandName(it, 'manager');

                      return Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.blueGrey.withOpacity(0.2)),
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.store)),
                          title: Text(
                            name.isEmpty ? '-' : name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (code.isNotEmpty) Text('Code: $code'),
                              if (phone.isNotEmpty) Text('Tel: $phone'),
                              Text('Region: $region • Manager: $manager'),
                            ],
                          ),
                          trailing: _canEdit
                              ? PopupMenuButton<String>(
                                  onSelected: (v) {
                                    if (v == 'edit') {
                                      _createOrEditDealer(existing: it);
                                    } else if (v == 'delete') {
                                      _deleteDealer(it);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, size: 18),
                                          SizedBox(width: 8),
                                          Text('Tahrirlash'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete,
                                              size: 18, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('O‘chirish'),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      );
                    },
                  ),
          ),
          if (_total > _perPage)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 2),
              child: Row(
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
            ),
        ],
      ),
    );
  }
}
