import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/loading.dart';

class DealerDebtScreen extends StatefulWidget {
  const DealerDebtScreen({super.key});

  @override
  State<DealerDebtScreen> createState() => _DealerDebtScreenState();
}

class _DealerDebtScreenState extends State<DealerDebtScreen> {
  bool _loading = true;
  String _error = '';
  List<Map<String, dynamic>> _dealers = [];

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final auth = context.read<AuthProvider>();
      final token = auth.token!;
      final managerId = auth.userId;

      // faqat o‘ziga biriktirilgan dillerlar:
      // backend’da dealers kolleksiyasida assigned_manager field bor deb hisoblaymiz
      final res = await ApiService.get(
        "collections/dealers/records?filter=assigned_manager='${managerId}'&perPage=100&sort=name",
        token: token,
      );
      setState(() =>
          _dealers = List<Map<String, dynamic>>.from(res['items'] as List));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  String _fmtDebt(Map<String, dynamic> d) {
    // kolleksiyada balans maydoni turlicha bo‘lishi mumkin:
    // 'balance_usd' yoki 'outstanding_usd' yoki hisoblangan view maydoni.
    final balance =
        d['balance_usd'] ?? d['outstanding_usd'] ?? d['debt_usd'] ?? 0;
    return '\$${balance.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mening dillerlarim — qarzdorlik"),
        actions: [
          IconButton(onPressed: _fetch, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Loading(text: 'Yuklanmoqda...')
          : _error.isNotEmpty
              ? Center(child: Text('Xato: $_error'))
              : _dealers.isEmpty
                  ? const Center(child: Text("Diller topilmadi"))
                  : ListView.separated(
                      itemCount: _dealers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final d = _dealers[i];
                        return ListTile(
                          leading: const Icon(Icons.store),
                          title: Text(d['name'] ?? d['id']),
                          subtitle: Text('TIN: ${d['tin'] ?? '-'}'),
                          trailing: Text(_fmtDebt(d),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
    );
  }
}
