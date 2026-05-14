import 'dart:convert';
import 'dart:io';

import '../config.dart';

class BackendApi {
  BackendApi(this._bearer);

  final String? _bearer;

  Map<String, String> get _headers => {
        HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
        if (_bearer != null) HttpHeaders.authorizationHeader: 'Bearer $_bearer',
      };

  Future<Map<String, dynamic>> getJson(String path) async {
    final uri = Uri.parse('$kApiBase$path');
    final client = HttpClient();
    try {
      final req = await client.getUrl(uri);
      _headers.forEach(req.headers.set);
      final resp = await req.close();
      final text = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(text);
      if (resp.statusCode >= 400) {
        throw BackendException(resp.statusCode, _errMsg(data));
      }
      return data as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) async {
    return _writeJson('POST', path, body);
  }

  Future<Map<String, dynamic>> patchJson(String path, Map<String, dynamic> body) async {
    return _writeJson('PATCH', path, body);
  }

  Future<Map<String, dynamic>> putJson(String path, Map<String, dynamic> body) async {
    return _writeJson('PUT', path, body);
  }

  Future<Map<String, dynamic>> deleteJson(String path) async {
    final uri = Uri.parse('$kApiBase$path');
    final client = HttpClient();
    try {
      final req = await client.openUrl('DELETE', uri);
      _headers.forEach(req.headers.set);
      final resp = await req.close();
      final text = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(text);
      if (resp.statusCode >= 400) {
        throw BackendException(resp.statusCode, _errMsg(data));
      }
      return data as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> _writeJson(
    String method,
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$kApiBase$path');
    final client = HttpClient();
    try {
      final req = await client.openUrl(method, uri);
      _headers.forEach(req.headers.set);
      req.write(jsonEncode(body));
      final resp = await req.close();
      final text = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(text);
      if (resp.statusCode >= 400) {
        throw BackendException(resp.statusCode, _errMsg(data));
      }
      return data as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  String _errMsg(dynamic data) {
    if (data is Map && data['error'] != null) return data['error'].toString();
    return 'Request failed';
  }
}

class BackendException implements Exception {
  BackendException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => 'BackendException($status): $message';
}
