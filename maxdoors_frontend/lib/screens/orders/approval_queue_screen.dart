import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/loading.dart';
import '../../models/order.dart';
import 'order_detail_screen.dart';

class ApprovalQueueScreen extends StatefulWidget {
  const ApprovalQueueScreen({super.key});

  @override
  State<ApprovalQueueScreen> createState() => _ApprovalQueueScreenState();
}

class _ApprovalQueueScreenState extends State<ApprovalQueueScreen> {
  bool _loading = true;
  String _error = '';
  List<Order> _items = [];
  int _page = 1;
  final int _perPage = 50;

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final token = context.read<AuthProvider>().token!;
      final res = await ApiService.get(
        "collections/orders/records?perPage=$_perPage&page=$_page"
        "&filter=${Uri.encodeComponent("status='edit_requested'")}"
        "&sort=-created&expand=dealer,region,manager,warehouse",
        token: token,
      );
      final items =
          (res['items'] as List).map((e) => Order.fromJson(e)).toList();
      setState(() => _items = items);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _setStatus(String id, String status) async {
    try {
      final token = context.read<AuthProvider>().token!;
      await ApiService.patch(
          "collections/orders/records/$id", {"status": status},
          token: token);
      _fetch();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Status: $status")),
        );
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
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().role ?? '';
    final canSee =
        role == 'warehouseman' || role == 'admin' || role == 'accountant';
    if (!canSee) {
      return const Scaffold(body: Center(child: Text("Sizda ruxsat yo‘q")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Approval Queue (edit_requested)'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch),
        ],
      ),
      body: _loading
          ? const Loading(text: 'Yuklanmoqda...')
          : _error.isNotEmpty
              ? Center(child: Text('Xato: $_error'))
              : _items.isEmpty
                  ? const Center(child: Text('Navbatda so‘rov yo‘q'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final o = _items[i];
                        return ListTile(
                          leading: const Icon(Icons.edit_note),
                          title: Text(o.numberOrId),
                          subtitle: Text(
                            'Dealer: ${o.dealerLabel} • Region: ${o.regionLabel} • Manager: ${o.managerLabel}',
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      OrderDetailScreen(orderId: o.id)),
                            );
                          },
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () => _setStatus(o.id,
                                    'created'), // rad etish → odatdagi holat
                                child: const Text('Reject'),
                              ),
                              ElevatedButton(
                                onPressed: () => _setStatus(o.id,
                                    'editable'), // tasdiq → tahrirga ruxsat
                                child: const Text('Approve'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
