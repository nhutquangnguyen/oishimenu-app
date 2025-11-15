import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // Load Supabase credentials from environment variables
  static String get url => dotenv.env['SUPABASE_URL'] ?? '';
  static String get anonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    try {
      // Load environment variables first
      await dotenv.load(fileName: ".env");

      // Validate that required environment variables are present
      if (url.isEmpty || anonKey.isEmpty) {
        throw Exception('Missing required Supabase environment variables');
      }

      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
        debug: false, // Disabled in production to prevent verbose logging
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          autoRefreshToken: true,
        ),
      );
      print('✅ Supabase initialized successfully');
    } catch (e) {
      print('⚠️ Supabase initialization failed: $e');
      // Continue app launch even if Supabase fails - allow offline usage
      // The app can still function with local data until connection is restored
    }
  }
}