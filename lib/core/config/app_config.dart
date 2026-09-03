import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.authRedirectUrl,
  });

  final String apiBaseUrl;
  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Deep link Supabase Auth redirects back to after email confirmation or
  /// password recovery. Keep it in sync with the Supabase project's allow-listed
  /// redirect URLs and the native URL scheme on Android/iOS.
  final String authRedirectUrl;

  factory AppConfig.fromEnvironment() {
    // Local development should be able to run from a checked-in structure plus a
    // machine-specific `.env`. We still keep `--dart-define` as fallback so CI or
    // release builds do not depend on bundling the same local file.
    return AppConfig(
      apiBaseUrl: _readValue('API_BASE_URL', fallback: 'http://localhost:3000'),
      supabaseUrl: _readValue('SUPABASE_URL'),
      supabaseAnonKey: _readValue('SUPABASE_ANON_KEY'),
      authRedirectUrl: _readValue(
        'AUTH_REDIRECT_URL',
        fallback: 'vzfood://auth-callback',
      ),
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
