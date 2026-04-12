import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:movieswipe/core/config/env_config.dart';
import 'package:movieswipe/core/errors/exceptions.dart';

/// HTTP API client wrapper with Supabase JWT auth
class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  /// Get auth headers with Supabase JWT token
  Map<String, String> get _headers {
    final session = Supabase.instance.client.auth.currentSession;
    return {
      'Content-Type': 'application/json',
      if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
    };
  }

  /// GET request
  Future<dynamic> get(String endpoint) async {
    try {
      final url = Uri.parse('${EnvConfig.baseUrl}$endpoint');
      final response = await _client
          .get(url, headers: _headers)
          .timeout(Duration(milliseconds: EnvConfig.apiTimeout));

      return _handleResponse(response);
    } catch (e) {
      throw NetworkException(message: 'Failed to connect to server: $e');
    }
  }

  /// POST request
  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final url = Uri.parse('${EnvConfig.baseUrl}$endpoint');
      final response = await _client
          .post(
            url,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(Duration(milliseconds: EnvConfig.apiTimeout));

      return _handleResponse(response);
    } catch (e) {
      throw NetworkException(message: 'Failed to connect to server: $e');
    }
  }

  /// DELETE request
  Future<dynamic> delete(String endpoint) async {
    try {
      final url = Uri.parse('${EnvConfig.baseUrl}$endpoint');
      final response = await _client
          .delete(url, headers: _headers)
          .timeout(Duration(milliseconds: EnvConfig.apiTimeout));

      return _handleResponse(response);
    } catch (e) {
      throw NetworkException(message: 'Failed to connect to server: $e');
    }
  }

  /// Handle HTTP response
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      throw ServerException(
        message: 'Server error: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }
}
