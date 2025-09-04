import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/order.dart';
import '../orders/order_detail_screen.dart';
import '../orders/order_create_screen.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  bool _loading = true;
  String _error = '';
  List<Order> _items = [];
  int _page = 1;
  final int _perPage = 30;
  int _total = 0;

  // filter/search
  final _searchCtrl = TextEditingController();
  String _query = '';
  // all | created | edit_requested | editable | packed | shipped
  String _status = 'all';
  String _sort = '-created';

  String get _basePath =>
      'collections/orders/records?perPage=$_perPage&page=$_page&sort=$_sort&expand=dealer,region,manager,warehouse';

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

  // ===== Helpers to safely read dynamic Order fields =====
  String? _getStr(dynamic v) => v == null ? null : v.toString();

  String? _humanIdAny(Order o) {
    final d = o as dynamic;
    dynamic v;
    try {
      v = d.humanId;
    } catch (_) {}
    v ??= () {
      try {
        return (o as dynamic).human_id;
      } catch (_) {
        return null;
      }
    }();
    final s = _getStr(v)?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  dynamic _dailySeqAny(Order o) {
    final d = o as dynamic;
    dynamic v;
    try {
      v = d.dailySeq;
    } catch (_) {}
    if (v == null) {
      try {
        v = d.daily_seq;
      } catch (_) {}
    }
    if (v == null) {
      try {
        v = d.dailyNumber;
      } catch (_) {}
    }
    if (v == null) {
      try {
        v = d.daily_number;
      } catch (_) {}
    }
    return v;
  }

  // Uzbek labels for statuses
  String _statusUz(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'created':
        return 'Yangi';
      case 'edit_requested':
        return "O'zgartirish so‘ralgan";
      case 'editable':
        return "O'zgartirish mumkin";
      case 'packed':
        return 'Yig‘ilgan';
      case 'shipped':
        return 'Jo‘natilgan';
      default:
        return '-';
    }
  }

  Future<void> _fetch({bool resetPage = false}) async {
    if (resetPage) _page = 1;
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final token = context.read<AuthProvider>().token!;
      final sb = StringBuffer(_basePath);

      // filters
      final filters = <String>[];
      if (_status != 'all') {
        filters.add("status='$_status'");
      }
      if (_query.isNotEmpty) {
        final safe = _query.replaceAll("'", r"\'");
        // human_id ni ham qidiruvga qo‘shamiz
        filters.add(
          "(human_id~'$safe' || number~'$safe' || daily_number~'$safe' || note~'$safe')",
        );
      }
      if (filters.isNotEmpty) {
        sb.write('&filter=${Uri.encodeComponent(filters.join(' && '))}');
      }

      final url = sb.toString();
      final res = await ApiService.get(url, token: token);

      final items = ((res['items'] as List?) ?? [])
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList();

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

  Future<void> _refresh() => _fetch(resetPage: true);

  // === UI helpers ===
  Color _statusColor(BuildContext context, String? status) {
    final s = (status ?? '').toLowerCase();
    final scheme = Theme.of(context).colorScheme;
    switch (s) {
      case 'created':
        return Colors.blue.shade400;
      case 'edit_requested':
        return Colors.orange.shade600;
      case 'editable':
        return Colors.teal.shade600;
      case 'packed':
        return Colors.deepPurple.shade500;
      case 'shipped':
        return Colors.green.shade600;
      default:
        return scheme.primary;
    }
  }

  Color _statusChipBg(BuildContext context, String? status) {
    final c = _statusColor(context, status);
    return c.withOpacity(0.12);
  }

  /// "NNN-dd.MM.yyyy" sarlavha
  /// 1) human_id bo‘lsa – o‘sha
  /// 2) bo‘lmasa: daily_seq + created dan formatlab
  /// 3) bo‘lmasa: number + created
  /// 4) bo‘lmasa: id
  String _orderHuman(Order o) {
    final human = (_humanIdAny(o) ?? '').trim();
    if (human.isNotEmpty) return human;

    DateTime? created;
    if ((o.created ?? '').isNotEmpty) {
      created = DateTime.tryParse(o.created!)?.toLocal();
    }
    String datePart = '';
    if (created != null) {
      final dd = created.day.toString().padLeft(2, '0');
      final mm = created.month.toString().padLeft(2, '0');
      final yyyy = created.year.toString();
      datePart = '$dd.$mm.$yyyy';
    }

    int? seq;
    final rawSeq = _dailySeqAny(o);
    if (rawSeq is num) {
      seq = rawSeq.toInt();
    } else if (rawSeq is String) {
      seq = int.tryParse(rawSeq);
    }

    if (seq != null && seq > 0 && datePart.isNotEmpty) {
      return '${seq.toString().padLeft(3, '0')}-$datePart';
    }

    final number = (o.number ?? '').trim();
    if (number.isNotEmpty && datePart.isNotEmpty) {
      return '$number-$datePart';
    }

    return o.id;
  }

  Widget _legend(BuildContext context) {
    final entries = const [
      ['created', Icons.fiber_new],
      ['edit_requested', Icons.edit_note],
      ['editable', Icons.edit],
      ['packed', Icons.inventory],
      ['shipped', Icons.local_shipping],
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: entries.map((e) {
        final s = e[0] as String;
        final ic = e[1] as IconData;
        final color = _statusColor(context, s);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ic, size: 16, color: color),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _statusChipBg(context, s),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.35)),
              ),
              child: Text(
                _statusUz(s).toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Widget _pill(BuildContext context, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().role ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buyurtmalar'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(22),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '/$_basePath',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetch(resetPage: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter panel
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    value: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Hammasi')),
                      DropdownMenuItem(value: 'created', child: Text('Yangi')),
                      DropdownMenuItem(
                        value: 'edit_requested',
                        child: Text("O'zgartirish so‘ralgan"),
                      ),
                      DropdownMenuItem(
                        value: 'editable',
                        child: Text("O'zgartirish mumkin"),
                      ),
                      DropdownMenuItem(
                        value: 'packed',
                        child: Text('Yig‘ilgan'),
                      ),
                      DropdownMenuItem(
                        value: 'shipped',
                        child: Text('Jo‘natilgan'),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _status = v ?? 'all');
                      _fetch(resetPage: true);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Qidirish (raqam / human_id / izoh)',
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _legend(context),
            ),
          ),
          const SizedBox(height: 6),

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
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Buyurtmalar topilmadi'),
                          const SizedBox(height: 10),
                          if (role == 'admin' || role == 'manager')
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const OrderCreateScreen(),
                                  ),
                                ).then((_) => _fetch(resetPage: true));
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Yangi buyurtma'),
                            ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final o = _items[i];
                        final color = _statusColor(context, o.status);
                        final bg = _statusChipBg(context, o.status);

                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    OrderDetailScreen(orderId: o.id),
                              ),
                            ).then((_) => _fetch()); // qaytganda yangilash
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: color.withOpacity(0.25)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  offset: const Offset(0, 2),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // chap indikator
                                  Container(
                                    width: 6,
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        bottomLeft: Radius.circular(12),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // yuqori qat: sarlavha + status chip + sana
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _orderHuman(o),
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: bg,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color:
                                                        color.withOpacity(0.35),
                                                  ),
                                                ),
                                                child: Text(
                                                  _statusUz(o.status)
                                                      .toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: color,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _formatDate(o.created),
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.color,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          // past qat: diller • menejer • region
                                          Wrap(
                                            spacing: 12,
                                            runSpacing: 6,
                                            children: [
                                              _pill(context, Icons.store,
                                                  o.dealerLabel),
                                              _pill(context, Icons.person,
                                                  o.managerLabel),
                                              _pill(context, Icons.map,
                                                  o.regionLabel),
                                            ],
                                          ),
                                          if ((o.note ?? '').isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              o.note!,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.color,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),

          // Pagination
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
