import 'api_service.dart';

class AuthService {
  static Future<Map<String, dynamic>> loginUser(
    String email,
    String password,
  ) async {
    return await ApiService.post("collections/users/auth-with-password", {
      "identity": email,
      "password": password,
    });
  }

  static Future<Map<String, dynamic>> loginAdmin(
    String email,
    String password,
  ) async {
    return await ApiService.post("admins/auth-with-password", {
      "identity": email,
      "password": password,
    }, isAdmin: true);
  }
}
