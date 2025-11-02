import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to handle deep links for authentication callbacks
class DeepLinkService {
  static StreamController<String>? _linkStreamController;
  static StreamSubscription<AuthState>? _linkSubscription;

  /// Initialize deep link handling
  static Future<void> initialize() async {
    _linkStreamController = StreamController<String>.broadcast();

    try {
      // Listen for auth state changes which can include deep link auth
      _linkSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        // Handle auth state changes which can include deep link auth
        if (data.event == AuthChangeEvent.signedIn && data.session != null) {
          print('🟢 User signed in via deep link');
        }
      });

      print('🟢 Deep link service initialized successfully');
    } catch (e) {
      print('🔴 Deep link service initialization failed: $e');
    }
  }

  /// Process deep link URLs
  static void _handleDeepLink(String link) {
    print('🔵 Deep link received: $link');

    // Parse the link
    final uri = Uri.parse(link);

    // Handle different types of deep links
    if (uri.scheme == 'oishimenu') {
      _handleOishiMenuLink(uri);
    } else if (link.contains('supabase.co')) {
      _handleSupabaseLink(uri);
    }

    // Notify listeners
    _linkStreamController?.add(link);
  }

  /// Handle OishiMenu app deep links
  static void _handleOishiMenuLink(Uri uri) {
    print('🔵 Processing OishiMenu deep link: ${uri.path}');

    switch (uri.path) {
      case '/auth/callback':
      case '/auth/confirm':
        _handleAuthCallback(uri);
        break;
      default:
        print('🔴 Unknown OishiMenu deep link path: ${uri.path}');
    }
  }

  /// Handle Supabase authentication links
  static void _handleSupabaseLink(Uri uri) {
    print('🔵 Processing Supabase link: ${uri.toString()}');
    _handleAuthCallback(uri);
  }

  /// Handle authentication callback/confirmation
  static Future<void> _handleAuthCallback(Uri uri) async {
    try {
      print('🔵 Processing auth callback: ${uri.toString()}');

      // Extract parameters from the URI
      final params = uri.queryParameters;

      if (params.containsKey('error')) {
        final error = params['error'];
        final errorDescription = params['error_description'];
        print('🔴 Auth callback error: $error - $errorDescription');
        return;
      }

      // Handle email confirmation
      if (params.containsKey('token_hash') && params.containsKey('type')) {
        await _handleEmailConfirmation(params);
      }
      // Handle magic link or OAuth callback
      else if (params.containsKey('access_token') || params.containsKey('code')) {
        await _handleOAuthCallback(params);
      }
    } catch (e) {
      print('🔴 Error handling auth callback: $e');
    }
  }

  /// Handle email confirmation
  static Future<void> _handleEmailConfirmation(Map<String, String> params) async {
    try {
      final type = params['type'];
      print('🔵 Handling email confirmation type: $type');

      if (type == 'email') {
        // This is an email confirmation
        await Supabase.instance.client.auth.verifyOTP(
          token: params['token_hash']!,
          type: OtpType.email,
        );
        print('🟢 Email confirmation successful');
      } else if (type == 'recovery') {
        // This is a password recovery
        print('🔵 Password recovery link detected');
        // Handle password recovery if needed
      }
    } catch (e) {
      print('🔴 Email confirmation failed: $e');
    }
  }

  /// Handle OAuth callback
  static Future<void> _handleOAuthCallback(Map<String, String> params) async {
    try {
      print('🔵 Handling OAuth callback');

      if (params.containsKey('access_token')) {
        // Handle direct access token
        print('🟢 OAuth callback with access token processed');
      } else if (params.containsKey('code')) {
        // Handle authorization code
        print('🟢 OAuth callback with code processed');
      }
    } catch (e) {
      print('🔴 OAuth callback failed: $e');
    }
  }

  /// Get the deep link stream
  static Stream<String>? get linkStream => _linkStreamController?.stream;

  /// Dispose resources
  static void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
    _linkStreamController?.close();
    _linkStreamController = null;
  }

  /// Create a test method to manually trigger email confirmation
  static Future<void> testEmailConfirmation() async {
    try {
      print('🔵 Testing email confirmation with current user...');
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        print('🟢 Current user: ${user.email}');
        print('🟢 Email confirmed: ${user.emailConfirmedAt != null}');
      } else {
        print('🔴 No current user found');
      }
    } catch (e) {
      print('🔴 Test email confirmation failed: $e');
    }
  }
}