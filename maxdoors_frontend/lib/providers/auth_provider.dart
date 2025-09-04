import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  String? _token;
  String? _role;
  String? _userId;
  String? _name;
  String? _email;

  bool get isAuthenticated => _token != null;
  String? get token => _token;
  String? get role => _role;
  String? get userId => _userId;
  String? get name => _name;
  String? get email => _email;

  AuthProvider() {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString("token");
    _role = prefs.getString("role");
    _userId = prefs.getString("userId");
    _name = prefs.getString("name");
    _email = prefs.getString("email");
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final res = await AuthService.loginUser(email, password);

    _token = res["token"];
    _role = res["role"] ?? '';
    _userId = res["userId"] ?? '';
    _name = res["name"] ?? ''; // <-- qo‘shildi
    _email = res["email"] ?? ''; // <-- qo‘shildi

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("token", _token!);
    await prefs.setString("role", _role!);
    await prefs.setString("userId", _userId!);
    if (_name != null && _name!.isNotEmpty) {
      await prefs.setString("name", _name!);
    }
    if (_email != null && _email!.isNotEmpty) {
      await prefs.setString("email", _email!);
    }

    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _role = null;
    _userId = null;
    _name = null;
    _email = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");
    await prefs.remove("role");
    await prefs.remove("userId");
    await prefs.remove("name");
    await prefs.remove("email");

    notifyListeners();
  }
}
