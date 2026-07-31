import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  final String apiBaseUrl;
  final String supabaseUrl;
  final String supabaseAnonKey;

  factory AppConfig.fromEnvironment() {
    // Local development should be able to run from a checked-in structure plus a
    // machine-specific `.env`. We still keep `--dart-define` as fallback so CI or
    // release builds do not depend on bundling the same local file.
    return AppConfig(
      apiBaseUrl: _readValue('API_BASE_URL', fallback: 'http://localhost:3000'),
      supabaseUrl: _readValue('SUPABASE_URL'),
      supabaseAnonKey: _readValue('SUPABASE_ANON_KEY'),
    );
  }

  bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static String _readValue(String key, {String fallback = ''}) {
    final dotenvValue = dotenv.env[key];
    if (dotenvValue != null && dotenvValue.isNotEmpty) {
      return dotenvValue;
    }

    return String.fromEnvironment(key, defaultValue: fallback);
  }
}
