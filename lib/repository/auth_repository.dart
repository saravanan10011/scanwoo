import 'package:quick_scanner/services/apiservice.dart';

class AuthRepository {
  final ApiService api = ApiService();

  Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await api.post(
      '/login',
      {
        'email': email,
        'password': password,
      },
    );

    return response;
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await api.post(
      '/auth/register',
      {
        'name': name,
        'email': email,
        'password': password,
      },
    );

    return response;
  }

  Future<Map<String, dynamic>> getProfile(
    String token,
  ) async {
    final response = await api.get(
      '/auth/profile',
      token: token,
    );

    return response;
  }
}