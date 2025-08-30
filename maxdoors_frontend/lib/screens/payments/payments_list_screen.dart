// lib/screens/payments/payments_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/payment.dart';
import 'payment_edit_screen.dart';
import 'payment_add_screen.dart';

class PaymentsListScreen extends StatefulWidget {
  const PaymentsListScreen({super.key});

  @override
  State<PaymentsListScreen> createState() => _PaymentsListScreenState();
}

class _PaymentsListScreenState extends State<PaymentsListScreen> {
  // MUMKIN BO'LGAN KOLLEKSIYA NOMLARI (birma-bir sinaymiz)
  static const List<String> _candidates = [
    'payments',
    'dealer_payments',
    'dealerPayments',
  ];

  String? _activeCollection; // qaysi kolleksiya ishladi
  bool _loading = true;
  String _error = '';
  List<Payment> _items = [];
  int _page = 1;
  final int _perPage = 30;
  int _total = 0;

  // filter/search
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _currency = 'all'; // all | USD | UZS
  String _method = 'all'; // all | cash | card | bank
  String _sort = '-date';

  // so‘nggi sinab ko‘rilgan URL va xom javob (debug oynasi uchun)
  String _lastUrl = '';
  Map<String, dynamic>? _lastRaw;

  String _buildBase(String col) =>
      'collections/$col/records?perPage=$_perPage&page=$_page&sort=$_sort&expand=dealer';

  String _filtersQuery() {
    final filters = <String>[];
    if (_currency != 'all') filters.add("currency='$_currency'");
    if (_method != 'all') filters.add("method='$_method'");
    if (_query.isNotEmpty) {
      final safe = _query.replaceAll("'", r"\'");
      filters.add("(note~'$safe')");
    }
    if (filters.isEmpty) return '';
    return '&filter=${Uri.encodeComponent(filters.join(' && '))}';
  }

  Future<bool> _tryFetch(String collection, String token) async {
    final url = _buildBase(collection) + _filtersQuery();
    _lastUrl = url;
    try {
      final res = await ApiService.get(url, token: token);
      _lastRaw = (res is Map<String, dynamic>) ? res : null;

      final list = (res['items'] as List?) ?? const [];
      final total = (res['totalItems'] as num?)?.toInt() ?? list.length;

      // DEBUG LOG
      // ignore: avoid_print
      print(
          'PAYMENTS TRY col="$collection" url="$url" totalItems=$total items.length=${list.length}');

      final items =
          list.map((e) => Payment.fromJson(e as Map<String, dynamic>)).toList();

      setState(() {
        _items = items;
        _total = total;
        _activeCollection = collection;
      });

      // muvaffaqiyat: kolleksiya mavjud va parsing OK
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('PAYMENTS TRY col="$collection" FAILED: $e');
      return false;
    }
  }

  Future<void> _fetch({bool resetPage = false}) async {
    if (resetPage) _page = 1;
    setState(() {
      _loading = true;
      _error = '';
      _lastRaw = null;
      _lastUrl = '';
    });

    try {
      final token = context.read<AuthProvider>().token!;
      bool ok = false;
      for (final name in _candidates) {
        ok = await _tryFetch(name, token);
        if (ok) break;
      }
      if (!ok) {
        setState(() {
          _error =
              'Hech bir kolleksiya nomi mos kelmadi (${_candidates.join(", ")}). '
              'Backenddagi payments kolleksiya nomini tekshiring.';
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _refresh() => _fetch(resetPage: true);

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

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('O‘chirish?'),
        content: const Text('To‘lovni o‘chirmoqchimisiz?'),
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
      final col = _activeCollection ?? _candidates.first;
      await ApiService.delete('collections/$col/records/$id', token: token);
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
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().role ?? '';
    final canEdit = role == 'admin' || role == 'accountant';
    final active = _activeCollection ?? '(aniqlanmoqda)';

    return Scaffold(
      appBar: AppBar(
        title: const Text('To‘lovlar'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(22),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Active: $active   |   ${_lastUrl.isEmpty ? "" : _lastUrl}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
            ),
          ),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.data_object),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Ko‘p ma’lumot / JSON'),
                    content: SingleChildScrollView(
                      child: Text(
                        _lastRaw == null ? '—' : _lastRaw.toString(),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Yopish')),
                    ],
                  ),
                );
              }),
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _fetch(resetPage: true)),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () async {
                final added = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const PaymentAddScreen()),
                );
                if (added == true && mounted) _fetch(resetPage: true);
              },
              icon: const Icon(Icons.add),
              label: const Text('To‘lov qo‘shish'),
            )
          : null,
      body: Column(
        children: [
          // Filter panel
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                // Currency
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<String>(
                    value: _currency,
                    decoration: const InputDecoration(
                      labelText: 'Valyuta',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Barchasi')),
                      DropdownMenuItem(value: 'USD', child: Text('USD')),
                      DropdownMenuItem(value: 'UZS', child: Text('UZS')),
                    ],
                    onChanged: (v) {
                      setState(() => _currency = v ?? 'all');
                      _fetch(resetPage: true);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Method
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    value: _method,
                    decoration: const InputDecoration(
                      labelText: 'Turi',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Barchasi')),
                      DropdownMenuItem(value: 'cash', child: Text('Naqd')),
                      DropdownMenuItem(value: 'card', child: Text('Karta')),
                      DropdownMenuItem(value: 'bank', child: Text('Bank')),
                    ],
                    onChanged: (v) {
                      setState(() => _method = v ?? 'all');
                      _fetch(resetPage: true);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Search by note
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Izoh bo‘yicha qidirish',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
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
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _items.isEmpty && !_loading
                  ? const Center(child: Text('To‘lovlar topilmadi'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final p = _items[i];
                        return Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Theme.of(context).dividerColor),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            leading: CircleAvatar(
                              child: Text((p.currency ?? '-').isNotEmpty
                                  ? (p.currency ?? '-')[0]
                                  : '-'),
                            ),
                            title: Text('${p.amountLabel} • ${p.dealerLabel}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Sana: ${_formatDate(p.date)}'),
                                if ((p.method ?? '').isNotEmpty)
                                  Text('Turi: ${p.method}'),
                                if ((p.note ?? '').isNotEmpty)
                                  Text('Izoh: ${p.note}'),
                              ],
                            ),
                            trailing: (role == 'admin' || role == 'accountant')
                                ? Wrap(
                                    spacing: 6,
                                    children: [
                                      IconButton(
                                        tooltip: 'Tahrirlash',
                                        icon: const Icon(Icons.edit),
                                        onPressed: () async {
                                          final updated =
                                              await Navigator.push<bool>(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  PaymentEditScreen(payment: {
                                                'id': p.id,
                                                'dealer': p.dealerId,
                                                'date':
                                                    p.date?.toIso8601String(),
                                                'amount': p.amount,
                                                'currency': p.currency,
                                                'method': p.method,
                                                'note': p.note,
                                                'rate': p.rate,
                                                'amount_usd': p.amountUsd,
                                              }),
                                            ),
                                          );
                                          if (updated == true && mounted)
                                            _fetch();
                                        },
                                      ),
                                      IconButton(
                                        tooltip: 'O‘chirish',
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () => _delete(p.id),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
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
