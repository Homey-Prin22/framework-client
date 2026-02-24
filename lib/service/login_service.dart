import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/machineinfo.dart';

class LoginService {
  static const String loginUrl = 'http://192.168.104.78:5001/login';
  static const String machineBaseUrl = 'http://192.168.104.78:5010/api/utils';

  static Future<Map<String, dynamic>> loginAndFetchMachines(String username, String password) async {
    try {
      final loginResponse = await http.post(
        Uri.parse(loginUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'username': username,
          'password': password,
        },
      );

      if (loginResponse.statusCode != 200) {
        throw Exception('Login failed: ${loginResponse.statusCode}');
      }


      final tokens = jsonDecode(loginResponse.body);
      final accessToken = tokens['access_token'];
      final refreshToken = tokens['refresh_token'];

      final uri = Uri.parse('$machineBaseUrl?username=$username&schema=true');

      final machineResponse = await http.get(uri);

      if (machineResponse.statusCode != 200) {
        throw Exception('Fetch machine failed: ${machineResponse.statusCode}');
      }

      final machineList = (jsonDecode(machineResponse.body) as List)
          .map((json) => MachineInfo.fromJson(json))
          .toList();

      return {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'machines': machineList,
      };
    } catch (e) {
      rethrow;
    }
  }
}
