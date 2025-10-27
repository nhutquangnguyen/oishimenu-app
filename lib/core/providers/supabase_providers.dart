import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import '../../services/supabase_service.dart';
import '../../models/user.dart';
import '../../features/auth/services/auth_service.dart';

/// Adapter to make SupabaseAuthService compatible with existing AuthService interface
class SupabaseAuthServiceAdapter extends AuthService {
  final SupabaseAuthService _supabaseAuthService = SupabaseAuthService();
  final StreamController<AppUser?> _localAuthStateController = StreamController<AppUser?>.broadcast();
  AppUser? _localCurrentUser;

  SupabaseAuthServiceAdapter() {
    // Listen to Supabase auth changes and convert to AppUser stream
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user;
      if (user != null) {
        // Convert Supabase User to AppUser
        final appUser = AppUser(
          id: user.id,
          email: user.email ?? '',
          fullName: user.userMetadata?['full_name'] ?? user.email ?? '',
          role: user.userMetadata?['role'] ?? 'staff',
          isActive: true,
          createdAt: _parseDateTime(user.createdAt),
          updatedAt: _parseDateTime(user.updatedAt ?? user.createdAt),
        );
        _localCurrentUser = appUser;
        _localAuthStateController.add(appUser);
      } else {
        _localCurrentUser = null;
        _localAuthStateController.add(null);
      }
    });
  }

  @override
  AppUser? get currentUser => _localCurrentUser;

  @override
  Stream<AppUser?> get authStateChanges => _localAuthStateController.stream;

  @override
  Future<AppUser?> signInWithEmailAndPassword({required String email, required String password}) async {
    try {
      print('🔵 Starting email login process...');
      print('🔵 Email: $email');

      final response = await _supabaseAuthService.signInWithEmailAndPassword(email, password);

      print('🔵 Supabase login response received');
      print('🔵 User logged in: ${response.user != null}');
      print('🔵 Session created: ${response.session != null}');

      if (response.user != null) {
        print('🟢 User login successful: ${response.user!.email}');
        return currentUser;
      }

      print('🔴 No user returned from login');
      return null;
    } on AuthException catch (e) {
      print('🔴 AuthException during login: ${e.message}');
      rethrow; // Re-throw AuthException as-is
    } catch (e) {
      print('🔴 Unexpected error during login: $e');
      print('🔴 Error type: ${e.runtimeType}');

      // Convert generic errors to AuthException for consistent UI handling
      if (e.toString().contains('invalid credentials') || e.toString().contains('Invalid login')) {
        throw AuthException('Invalid email or password. Please check your credentials.');
      } else if (e.toString().contains('email_not_confirmed')) {
        throw AuthException('Please check your email and confirm your account.');
      } else if (e.toString().contains('network')) {
        throw AuthException('Network error. Please check your internet connection.');
      } else {
        throw AuthException('Login failed. Please try again.');
      }
    }
  }

  @override
  Future<AppUser?> createUserWithEmailAndPassword({required String email, required String password, String? displayName}) async {
    try {
      print('🔵 Starting email signup process...');
      print('🔵 Email: $email');
      print('🔵 Display Name: ${displayName ?? 'Not provided'}');

      final response = await _supabaseAuthService.signUp(email, password, fullName: displayName);

      print('🔵 Supabase signup response received');
      print('🔵 User created: ${response.user != null}');
      print('🔵 Session created: ${response.session != null}');

      if (response.user != null) {
        print('🟢 User signup successful: ${response.user!.email}');
        return currentUser;
      }

      print('🔴 No user returned from signup');
      return null;
    } on AuthException catch (e) {
      print('🔴 AuthException during signup: ${e.message}');
      rethrow; // Re-throw AuthException as-is
    } catch (e) {
      print('🔴 Unexpected error during signup: $e');
      print('🔴 Error type: ${e.runtimeType}');

      // Convert generic errors to AuthException for consistent UI handling
      if (e.toString().contains('already registered')) {
        throw AuthException('An account with this email already exists.');
      } else if (e.toString().contains('invalid email')) {
        throw AuthException('Please enter a valid email address.');
      } else if (e.toString().contains('weak password')) {
        throw AuthException('Password is too weak. Please choose a stronger password.');
      } else {
        throw AuthException('Account creation failed. Please try again.');
      }
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _supabaseAuthService.signOut();
      _localCurrentUser = null;
      _localAuthStateController.add(null);
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  /// Google Sign-In functionality
  @override
  Future<AppUser?> signInWithGoogle() async {
    try {
      final response = await _supabaseAuthService.signInWithGoogle();
      if (response.user != null) {
        return currentUser;
      }
      return null;
    } catch (e) {
      throw Exception('Google sign-in failed: $e');
    }
  }

  /// Helper method to safely parse DateTime from various formats
  DateTime _parseDateTime(dynamic dateValue) {
    if (dateValue == null) {
      return DateTime.now();
    }

    try {
      // If it's already a DateTime, return as-is
      if (dateValue is DateTime) {
        return dateValue;
      }

      // If it's a string, try to parse it
      if (dateValue is String) {
        return DateTime.parse(dateValue);
      }

      // If it's a number (timestamp in milliseconds or seconds)
      if (dateValue is int) {
        // Check if it's in milliseconds (13 digits) or seconds (10 digits)
        if (dateValue.toString().length == 13) {
          return DateTime.fromMillisecondsSinceEpoch(dateValue);
        } else {
          return DateTime.fromMillisecondsSinceEpoch(dateValue * 1000);
        }
      }

      // Fallback to current time
      print('🔴 Warning: Could not parse dateValue: $dateValue (${dateValue.runtimeType})');
      return DateTime.now();
    } catch (e) {
      print('🔴 Error parsing dateValue: $dateValue, error: $e');
      return DateTime.now();
    }
  }
}

/// Supabase service providers to replace SQLite services
/// Use these providers throughout your app for cloud database access

// Menu Service Provider
final supabaseMenuServiceProvider = Provider<SupabaseMenuService>((ref) {
  return SupabaseMenuService();
});

// Customer Service Provider
final supabaseCustomerServiceProvider = Provider<SupabaseCustomerService>((ref) {
  return SupabaseCustomerService();
});

// Order Service Provider
final supabaseOrderServiceProvider = Provider<SupabaseOrderService>((ref) {
  return SupabaseOrderService();
});

// Menu Option Service Provider
final supabaseMenuOptionServiceProvider = Provider<SupabaseMenuOptionService>((ref) {
  return SupabaseMenuOptionService();
});

// Auth Service Provider - compatible with existing AuthService interface
final supabaseAuthServiceProvider = Provider<AuthService>((ref) {
  return SupabaseAuthServiceAdapter();
});

/// Migration helpers - use these to gradually switch from SQLite to Supabase
/// You can use both side-by-side during migration

// Legacy SQLite providers (keep during migration)
// final menuServiceProvider = Provider<MenuService>((ref) => MenuService());
// final orderServiceProvider = Provider<OrderService>((ref) => OrderService());
// final customerServiceProvider = Provider<CustomerService>((ref) => CustomerService());

/// Hybrid provider - choose between SQLite and Supabase
/// Set useSupabase = true to switch to cloud database
final useSupabaseProvider = StateProvider<bool>((ref) => true); // Set to true for Supabase

// Dynamic menu service - switches based on useSupabase setting
final dynamicMenuServiceProvider = Provider<dynamic>((ref) {
  final useSupabase = ref.watch(useSupabaseProvider);
  if (useSupabase) {
    return ref.watch(supabaseMenuServiceProvider);
  } else {
    // Return SQLite service (uncomment when needed)
    // return ref.watch(menuServiceProvider);
    return ref.watch(supabaseMenuServiceProvider); // Default to Supabase
  }
});

// Dynamic order service
final dynamicOrderServiceProvider = Provider<dynamic>((ref) {
  final useSupabase = ref.watch(useSupabaseProvider);
  if (useSupabase) {
    return ref.watch(supabaseOrderServiceProvider);
  } else {
    return ref.watch(supabaseOrderServiceProvider); // Default to Supabase
  }
});

// Dynamic customer service
final dynamicCustomerServiceProvider = Provider<dynamic>((ref) {
  final useSupabase = ref.watch(useSupabaseProvider);
  if (useSupabase) {
    return ref.watch(supabaseCustomerServiceProvider);
  } else {
    return ref.watch(supabaseCustomerServiceProvider); // Default to Supabase
  }
});