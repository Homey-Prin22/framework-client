import 'package:flutter/material.dart';
import '../model/machineinfo.dart';
import '../service/login_service.dart';

class LoginViewModel extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _accessToken;
  String? _refreshToken;
  List<MachineInfo> _machines = [];

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  List<MachineInfo> get machines => _machines;

  Future<void> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await LoginService.loginAndFetchMachines(username, password);
      _accessToken = result['access_token'];
      _refreshToken = result['refresh_token'];
      _machines = result['machines'];
    } catch (e) {
      _accessToken = null;
      _refreshToken = null;
      _machines = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
