import 'package:flutter/material.dart';
import 'package:quick_scanner/repository/auth_repository.dart';
class AuthController extends ChangeNotifier {
  final AuthRepository _repository = AuthRepository();
  bool isLoading = false;
  String? errorMessage;
  String? token;
  Map<String, dynamic>? _user;

  bool get _isLoading => _isLoading;
  String? get _errorMessage => _errorMessage;
  bool get _isLoggedIn => _token != null;
  String? get _token => _token;
  Map<String, dynamic>? get user => _user;

  Future<bool> login(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final data = await _repository.login(email, password);
      token = data['token'];
      _user = data['user'];
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

  Future<bool> register(String name, String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final data = await _repository.register(
        name: name, email: email, password: password,
      );
      token = data['token'];
      _user = data['user'];
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
    if (token != null) {
      try {
        await _repository.logout(token!);
      } catch (_) {}
    }
    token = null;
    _user = null;
    notifyListeners();
  }
}