import 'api_service.dart';

class AuthService {
  /// Foydalanuvchi (collections/users) bilan login.
  /// Natija: { token, userId, role, name, email, raw }
  static Future<Map<String, dynamic>> loginUser(
    String email,
    String password,
  ) async {
    final res = await ApiService.post(
      "collections/users/auth-with-password",
      {"identity": email, "password": password},
    );

    // PocketBase javobi: { token, record: {...} }
    final token = (res['token'] ?? '').toString();
    final record = (res['record'] as Map?) ?? const {};

    final userId = _pickFirstString(record, [
      'id',
    ]);
    final role = _pickFirstString(record, [
          'role',
        ]) ??
        'user';

    final name = _pickFirstString(record, [
          'name',
          'full_name',
          'fullName',
          'username',
          'displayName',
        ]) ??
        userId ??
        'Foydalanuvchi';

    final mail = _pickFirstString(record, [
          'email',
          'login',
          'username',
        ]) ??
        email;

    return {
      "token": token,
      "userId": userId ?? '',
      "role": role,
      "name": name,
      "email": mail,
      "raw": res,
    };
  }

  /// Admin (admins) bilan login.
  /// Natija: { token, userId, role:'admin', name, email, raw }
  static Future<Map<String, dynamic>> loginAdmin(
    String email,
    String password,
  ) async {
    final res = await ApiService.post(
      "admins/auth-with-password",
      {"identity": email, "password": password},
      isAdmin: true,
    );

    // Admin auth: { token, admin: {...} }
    final token = (res['token'] ?? '').toString();
    final admin = (res['admin'] as Map?) ?? const {};

    final adminId = _pickFirstString(admin, ['id']) ?? '';
    final name = _pickFirstString(admin, [
          'name',
          'full_name',
          'fullName',
          'username',
          'displayName',
        ]) ??
        'Administrator';
    final mail =
        _pickFirstString(admin, ['email', 'login', 'username']) ?? email;

    return {
      "token": token,
      "userId": adminId,
      "role": "admin",
      "name": name,
      "email": mail,
      "raw": res,
    };
  }

  /// Bir nechta ehtimoliy kalitlardan birinchisini string qilib qaytaradi
  static String? _pickFirstString(Map data, List<String> keys) {
    for (final k in keys) {
      if (data.containsKey(k) && data[k] != null) {
        final v = data[k].toString().trim();
        if (v.isNotEmpty) return v;
      }
    }
    return null;
  }
}
