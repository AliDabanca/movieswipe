import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:movieswipe/core/config/env_config.dart';
import 'package:movieswipe/core/errors/exceptions.dart';

/// HTTP API client wrapper
class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  /// GET request
  Future<dynamic> get(String endpoint) async {
    try {
      final url = Uri.parse('${EnvConfig.baseUrl}$endpoint');
      print('🌐 REQUESTING TO: $url'); // Debug print
      final response = await _client
          .get(url)
          .timeout(Duration(milliseconds: EnvConfig.apiTimeout));

      return _handleResponse(response);
    } catch (e) {
      print('❌ REQUEST FAILED: $e'); // Debug print
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
      print('🌐 POSTING TO: $url'); // Debug print
      print('📦 BODY: $body'); // Debug print
      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(Duration(milliseconds: EnvConfig.apiTimeout));

      return _handleResponse(response);
    } catch (e) {
      print('❌ POST FAILED: $e'); // Debug print
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
