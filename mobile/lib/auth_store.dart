import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'config.dart';

class AuthStore extends ChangeNotifier {
  final _secure = const FlutterSecureStorage();
  String? _token;

  String? get token => _token;

  Future<void> loadToken() async {
    _token = await _secure.read(key: 'jwt');
    notifyListeners();
  }

  Future<void> setToken(String? value) async {
    _token = value;
    if (value == null) {
      await _secure.delete(key: 'jwt');
    } else {
      await _secure.write(key: 'jwt', value: value);
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> register({
    required String phoneE164,
    required String password,
    String displayName = '',
  }) async {
    final res = await _post(
      '/api/auth/register',
      {
        'phoneE164': phoneE164,
        'password': password,
        'displayName': displayName,
      },
    );
    final token = res['token'] as String?;
    if (token != null) await setToken(token);
    return res;
  }

  Future<Map<String, dynamic>> login({
    required String phoneE164,
    required String password,
  }) async {
    final res = await _post(
      '/api/auth/login',
      {'phoneE164': phoneE164, 'password': password},
    );
    final token = res['token'] as String?;
    if (token != null) await setToken(token);
    return res;
  }

  Future<void> logout() => setToken(null);

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$kApiBase$path');
    final client = HttpClient();
    try {
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
      final resp = await req.close();
      final text = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(text) as Map<String, dynamic>;
      if (resp.statusCode >= 400) {
        throw ApiException(
          resp.statusCode,
          data['error']?.toString() ?? 'Request failed',
        );
      }
      return data;
    } finally {
      client.close();
    }
  }
}

class ApiException implements Exception {
  ApiException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => 'ApiException($status): $message';
}
