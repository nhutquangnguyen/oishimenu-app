import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../../../models/user.dart';

// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  throw UnimplementedError('AuthService should be overridden in main.dart');
});

// Auth state provider - listens to local auth state changes
final authStateProvider = StreamProvider<AppUser?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

// Current user provider
final currentUserProvider = Provider<AppUser?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user,
    loading: () => null,
    error: (_, __) => null,
  );
});

// Is authenticated provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null;
});

// User display name provider
final userDisplayNameProvider = Provider<String>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.fullName ?? user?.email ?? 'User';
});

// User email provider
final userEmailProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.email;
});

// User role provider
final userRoleProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.role;
});

// Auth loading provider for UI states
final authLoadingProvider = StateProvider<bool>((ref) => false);

// Auth error provider for error handling
final authErrorProvider = StateProvider<String?>((ref) => null);