import 'package:flutter/material.dart';
import 'package:quick_scanner/repository/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthController extends ChangeNotifier {
  final AuthRepository _repository = AuthRepository();

  bool isLoading = false;
  String? errorMessage;
  String? token;
  Map<String, dynamic>? _user;

  bool get isLoggedIn => token != null;

  Map<String, dynamic>? get user => _user;

  Future<bool> login(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final data = await _repository.login(email, password);

      token = data['token'];
      _user = data['user'];

      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userEmail', email);

      if (data['token'] != null) {
        await prefs.setString(
          'token',
          data['token'].toString(),
        );
      }

      isLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      errorMessage = e.toString().replaceAll('Exception: ', '');
      isLoading = false;
      notifyListeners();

      return false;
    }
  }

  Future<bool> register(
    String name,
    String email,
    String password,
  ) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final data = await _repository.register(
        name: name,
        email: email,
        password: password,
      );

      token = data['token'];
      _user = data['user'];

      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userName', name);
      await prefs.setString('userEmail', email);

      if (data['token'] != null) {
        await prefs.setString(
          'token',
          data['token'].toString(),
        );
      }

      isLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      errorMessage = e.toString().replaceAll('Exception: ', '');
      isLoading = false;
      notifyListeners();

      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.clear();

    token = null;
    _user = null;
    errorMessage = null;
    isLoading = false;

    notifyListeners();
  }
}