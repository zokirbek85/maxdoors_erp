class AppUser {
  final String id;
  final String email;
  final String role;

  AppUser({required this.id, required this.email, required this.role});

  factory AppUser.fromJson(Map<String, dynamic> j) {
    return AppUser(
      id: j['id'] ?? '',
      email: j['email'] ?? '',
      role: j['role'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'email': email, 'role': role};
}
