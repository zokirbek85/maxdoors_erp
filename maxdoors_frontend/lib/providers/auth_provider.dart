import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  String? _token;
  String? _role;
  String? _userId;

  bool get isAuthenticated => _token != null;
  String? get token => _token;
  String? get role => _role;
  String? get userId => _userId;

  AuthProvider() {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString("token");
    _role = prefs.getString("role");
    _userId = prefs.getString("userId");
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final res = await AuthService.loginUser(email, password);
    _token = res["token"];
    _role = res["record"]?["role"] ?? '';
    _userId = res["record"]?["id"] ?? '';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("token", _token!);
    await prefs.setString("role", _role!);
    await prefs.setString("userId", _userId!);

    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _role = null;
    _userId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");
    await prefs.remove("role");
    await prefs.remove("userId");
    notifyListeners();
  }
}
