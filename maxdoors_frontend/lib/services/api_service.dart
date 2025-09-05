import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Eslatma: Android emulyatorda test qilsangiz, 127.0.0.1 o‘rniga 10.0.2.2 ishlating.
  static const String baseUrl = "http://127.0.0.1:8090/api";

  static Map<String, String> _headers({String? token, bool isAdmin = false}) =>
      {
        "Content-Type": "application/json",
        if (token != null)
          "Authorization": isAdmin ? "Admin $token" : "Bearer $token",
      };

  static Uri _u(String path) => Uri.parse("$baseUrl/$path");

  static Future<Map<String, dynamic>> get(String path,
      {String? token, bool isAdmin = false}) async {
    final res = await http.get(_u(path),
        headers: _headers(token: token, isAdmin: isAdmin));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body);
    }
    throw Exception("API GET Error ${res.statusCode}: ${res.body}");
  }

  static Future<Map<String, dynamic>> post(
      String path, Map<String, dynamic> body,
      {String? token, bool isAdmin = false}) async {
    final res = await http.post(_u(path),
        headers: _headers(token: token, isAdmin: isAdmin),
        body: jsonEncode(body));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body);
    }
    throw Exception("API POST Error ${res.statusCode}: ${res.body}");
  }

  static Future<Map<String, dynamic>> patch(
      String path, Map<String, dynamic> body,
      {String? token, bool isAdmin = false}) async {
    final res = await http.patch(_u(path),
        headers: _headers(token: token, isAdmin: isAdmin),
        body: jsonEncode(body));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body);
    }
    throw Exception("API PATCH Error ${res.statusCode}: ${res.body}");
  }

  static Future<void> delete(String path,
      {String? token, bool isAdmin = false}) async {
    final res = await http.delete(_u(path),
        headers: _headers(token: token, isAdmin: isAdmin));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return;
    }
    throw Exception("API DELETE Error ${res.statusCode}: ${res.body}");
  }
}
