import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class UserEditScreen extends StatefulWidget {
  final String? userId; // null => create
  final Map<String, dynamic>? initial; // edit uchun

  const UserEditScreen({super.key, this.userId, this.initial});

  @override
  State<UserEditScreen> createState() => _UserEditScreenState();
}

class _UserEditScreenState extends State<UserEditScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _password2Ctrl = TextEditingController();

  String _role = 'manager'; // default
  bool _active = true;
  bool _saving = false;

  final _roles = const [
    'admin',
    'accountant',
    'manager',
    'warehouseman',
    'owner',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      final u = widget.initial!;
      _emailCtrl.text = (u['email'] ?? '').toString();
      _nameCtrl.text = (u['name'] ?? '').toString();
      _role = (u['role'] ?? 'manager').toString();
      // active flag turlicha bo‘lishi mumkin: active / is_active / verified
      _active =
          (u['active'] ?? u['is_active'] ?? u['verified'] ?? true) == true;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    _password2Ctrl.dispose();
    super.dispose();
  }

  // PocketBase foydalanuvchi payloadini tayyorlash
  Map<String, dynamic> _buildPayload({required bool create}) {
    final body = <String, dynamic>{
      'email': _emailCtrl.text.trim(),
      'name': _nameCtrl.text.trim(),
      'role': _role,
      // verified yuborilmaydi (readonly); sizdagi schema bo‘yicha:
      'is_active': _active, // agar sizda 'active' bo‘lsa pastdagini ishlating
      // 'active': _active,
      'emailVisibility': true, // foydali, lekin ixtiyoriy
    };

    if (create || _passwordCtrl.text.isNotEmpty) {
      body['password'] = _passwordCtrl.text;
      body['passwordConfirm'] = _password2Ctrl.text;
    }
    return body;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final token = context.read<AuthProvider>().token!;
      final createMode = widget.userId == null;
      final body = _buildPayload(create: createMode);

      if (createMode) {
        await ApiService.post('collections/users/records', body, token: token);
      } else {
        await ApiService.patch(
          'collections/users/records/${widget.userId}',
          body,
          token: token,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(createMode
              ? 'Foydalanuvchi yaratildi'
              : 'Foydalanuvchi saqlandi'),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      // API xabarini aniqroq chiqarish
      final msg = e.toString();
      String pretty = msg;
      if (msg.contains('"data":')) {
        pretty = 'Xato: maydonlar qiymatini tekshiring (parol tasdiqlash, '
            'email noyobligi, va boshqalar). $msg';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(pretty)));
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.userId == null
        ? 'Foydalanuvchi yaratish'
        : 'Foydalanuvchini tahrirlash';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email majburiy';
                if (!v.contains('@')) return 'Email noto‘g‘ri';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name (ixtiyoriy)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _role,
              decoration: const InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
              ),
              items: _roles
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => setState(() => _role = v ?? _role),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              title: const Text('Faol (active)'),
              subtitle:
                  const Text('O‘chirilsa, foydalanuvchi tizimga kira olmaydi'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordCtrl,
              decoration: InputDecoration(
                labelText: widget.userId == null
                    ? 'Parol (majburiy)'
                    : 'Parol (o‘zgartirish ixtiyoriy)',
                border: const OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (v) {
                if (widget.userId == null) {
                  if (v == null || v.isEmpty) return 'Parol majburiy';
                  if (v.length < 6)
                    return 'Kamida 6 ta belgidan iborat bo‘lsin';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password2Ctrl,
              decoration: InputDecoration(
                labelText: widget.userId == null
                    ? 'Parol tasdiqlash (majburiy)'
                    : 'Parol tasdiqlash (ixtiyoriy)',
                border: const OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (v) {
                if (_passwordCtrl.text.isNotEmpty || widget.userId == null) {
                  if (v != _passwordCtrl.text) return 'Parollar mos emas';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_saving ? 'Saqlanmoqda...' : 'Saqlash'),
            ),
          ],
        ),
      ),
    );
  }
}
