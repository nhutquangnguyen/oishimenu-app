import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
          createdAt: DateTime.parse(user.createdAt),
          updatedAt: DateTime.parse(user.updatedAt ?? user.createdAt),
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
      final response = await _supabaseAuthService.signInWithEmailAndPassword(email, password);
      if (response.user != null) {
        return currentUser;
      }
      return null;
    } catch (e) {
      throw Exception('Authentication failed: $e');
    }
  }

  @override
  Future<AppUser?> createUserWithEmailAndPassword({required String email, required String password, String? displayName}) async {
    try {
      final response = await _supabaseAuthService.signUp(email, password, fullName: displayName);
      if (response.user != null) {
        return currentUser;
      }
      return null;
    } catch (e) {
      throw Exception('Account creation failed: $e');
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