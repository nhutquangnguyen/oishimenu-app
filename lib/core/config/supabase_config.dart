import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // TODO: Replace with your actual Supabase project URL and anon key
  // You can find these in your Supabase dashboard: https://app.supabase.com/
  static const String url = 'https://jqjpxhgxuwkvvmvannut.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpxanB4aGd4dXdrdnZtdmFubnV0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEzOTAwMjksImV4cCI6MjA3Njk2NjAyOX0.iXNOT2Cf3NkqDGHh6S9f-HALdCjZ7D1_i2tKK6J1-E8';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    try {
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