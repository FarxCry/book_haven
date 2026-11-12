class UserSession {
  static Map<String, dynamic>? currentUser;

  static bool get isAdmin => currentUser != null && currentUser!['role'] == 'admin';

  static int get userId {
    final id = currentUser?['id'];
    return id is num ? id.toInt() : 0;
  }

  static String get name => (currentUser?['name'] ?? 'Reader').toString();

  static void logout() {
    currentUser = null;
  }
}
