import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthProvider {
  static const _storage = FlutterSecureStorage();

  Future<String?> getToken() async {
    try {
      final token = await _storage.read(key: 'access_token');
      return token;
    } catch (e) {
      print('Error getting token: $e');
      return null;
    }
  }
}
