import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration manager
/// Supports multiple environments: dev, test, prod
class EnvConfig {
  static String get baseUrl => dotenv.env['BASE_URL'] ?? 'http://127.0.0.1:8000';
  static int get apiTimeout => int.parse(dotenv.env['API_TIMEOUT'] ?? '30000');
  static String get environment => dotenv.env['ENVIRONMENT'] ?? 'development';
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  
  /// Check if running in production
  static bool get isProduction => environment == 'production';
  
  /// Check if running in development
  static bool get isDevelopment => environment == 'development';
  
  /// Check if running in test
  static bool get isTest => environment == 'test';

  /// Initialize environment variables
  /// Use [flavor] parameter to load specific environment:
  /// - 'dev' → loads .env.dev
  /// - 'test' → loads .env.test
  /// - 'prod' → loads .env.prod
  /// - null → loads .env (default)
  static Future<void> init({String? flavor}) async {
    String fileName = '.env';
    
    if (flavor != null) {
      fileName = '.env.$flavor';
    }
    
    await dotenv.load(fileName: fileName);
    print('🌍 Environment loaded: $fileName');
    print('📍 BASE_URL: $baseUrl');
    print('⚙️  ENVIRONMENT: $environment');
  }
}
