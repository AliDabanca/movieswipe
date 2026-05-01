import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration manager
/// Supports multiple environments: dev, test, prod
class EnvConfig {
  /// Returns the appropriate base URL based on the current platform and environment.
  /// 
  /// Logic:
  /// - Web/Windows/iOS Sim: Uses BASE_URL from .env (localhost)
  /// - Android Emulator: Uses 10.0.2.2 (alias for host localhost)
  /// - Physical Mobile: Uses PC_IP from .env (the local IP of the dev machine)
  static String get baseUrl {
    final rawBaseUrl = dotenv.env['BASE_URL'] ?? 'http://127.0.0.1:8000';
    
    // In production, we always use the defined base URL
    if (isProduction) return rawBaseUrl;

    if (!kIsWeb) {
      if (Platform.isAndroid) {
        // Check if running on an emulator
        // Simple heuristic: if BASE_URL is localhost/127.0.0.1, we need to map it
        if (rawBaseUrl.contains('localhost') || rawBaseUrl.contains('127.0.0.1')) {
          // If you set PC_IP in .env, we use that for physical devices.
          // Otherwise, we default to 10.0.2.2 for emulator.
          final pcIp = dotenv.env['PC_IP'] ?? 'localhost';
          
          if (pcIp != 'localhost') {
            return rawBaseUrl.replaceAll('localhost', pcIp).replaceAll('127.0.0.1', pcIp);
          }
          
          // Default android emulator mapping
          return rawBaseUrl.replaceAll('localhost', '10.0.2.2').replaceAll('127.0.0.1', '10.0.2.2');
        }
      }
    }
    
    return rawBaseUrl;
  }

  static int get apiTimeout => int.parse(dotenv.env['API_TIMEOUT'] ?? '30000');
  static String get environment => dotenv.env['ENVIRONMENT'] ?? 'development';
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  
  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';
  static bool get isTest => environment == 'test';

  static Future<void> init({String? flavor}) async {
    String fileName = '.env';
    
    if (flavor != null) {
      fileName = '.env.$flavor';
    }
    
    await dotenv.load(fileName: fileName);
    debugPrint('🌍 Environment loaded: $fileName');
    debugPrint('📍 Effective BASE_URL: $baseUrl');
    debugPrint('⚙️  ENVIRONMENT: $environment');
  }
}
