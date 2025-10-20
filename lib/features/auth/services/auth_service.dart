import 'dart:async';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../../services/database_helper.dart';
import '../../../models/user.dart';

class AuthService {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final StreamController<AppUser?> _authStateController = StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;

  // Get current user
  AppUser? get currentUser => _currentUser;

  // Auth state changes stream
  Stream<AppUser?> get authStateChanges => _authStateController.stream;

  // Check if running on web
  bool get _isWeb => kIsWeb;

  // Initialize auth service
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');

    if (userDataString != null) {
      try {
        final userData = jsonDecode(userDataString);
        _currentUser = AppUser(
          id: userData['id'],
          email: userData['email'],
          fullName: userData['fullName'],
          role: userData['role'],
          isActive: userData['isActive'],
          createdAt: DateTime.fromMillisecondsSinceEpoch(userData['createdAt']),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(userData['updatedAt']),
        );
        _authStateController.add(_currentUser);
      } catch (e) {
        // If there's an error parsing user data, clear it
        await prefs.remove('user_data');
        await prefs.remove('current_user_id');
      }
    }
  }

  // Sign in with email and password
  Future<AppUser?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      if (_isWeb) {
        return _signInWeb(email, password);
      } else {
        return _signInDatabase(email, password);
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('An unexpected error occurred. Please try again.');
    }
  }

  // Web-compatible sign in using SharedPreferences
  Future<AppUser?> _signInWeb(String email, String password) async {
    // Check for demo admin account
    if (email == 'admin@oishimenu.com' && password == 'admin123') {
      final user = AppUser(
        id: '1',
        email: email,
        fullName: 'System Administrator',
        role: 'admin',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      _currentUser = user;

      // Save current user to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_id', user.id);
      await prefs.setString('user_data', jsonEncode({
        'id': user.id,
        'email': user.email,
        'fullName': user.fullName,
        'role': user.role,
        'isActive': user.isActive,
        'createdAt': user.createdAt.millisecondsSinceEpoch,
        'updatedAt': user.updatedAt.millisecondsSinceEpoch,
      }));

      _authStateController.add(_currentUser);
      return user;
    }

    // Check for stored users in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final storedUsers = prefs.getStringList('users') ?? [];

    for (final userJson in storedUsers) {
      final userData = jsonDecode(userJson);
      if (userData['email'] == email && userData['password'] == _hashPassword(password)) {
        final user = AppUser(
          id: userData['id'],
          email: userData['email'],
          fullName: userData['fullName'],
          role: userData['role'],
          isActive: userData['isActive'],
          createdAt: DateTime.fromMillisecondsSinceEpoch(userData['createdAt']),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(userData['updatedAt']),
        );

        _currentUser = user;
        await prefs.setString('current_user_id', user.id);
        await prefs.setString('user_data', userJson);

        _authStateController.add(_currentUser);
        return user;
      }
    }

    throw AuthException('Invalid email or password.');
  }

  // Database sign in using SQLite
  Future<AppUser?> _signInDatabase(String email, String password) async {
    final db = await _databaseHelper.database;
    final hashedPassword = _hashPassword(password);

    final List<Map<String, dynamic>> users = await db.query(
      'users',
      where: 'email = ? AND password_hash = ? AND is_active = ?',
      whereArgs: [email, hashedPassword, 1],
      limit: 1,
    );

    if (users.isEmpty) {
      throw AuthException('Invalid email or password.');
    }

    final user = AppUser.fromMap(users.first);
    _currentUser = user;

    // Save current user to preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user_id', user.id);

    _authStateController.add(_currentUser);
    return user;
  }

  // Create user with email and password
  Future<AppUser?> createUserWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUsers = prefs.getStringList('users') ?? [];

      // Check if user already exists
      for (final userJson in storedUsers) {
        final userData = jsonDecode(userJson);
        if (userData['email'] == email) {
          throw AuthException('An account already exists for that email.');
        }
      }

      // Validate password strength
      if (password.length < 6) {
        throw AuthException('Password must be at least 6 characters long.');
      }

      final now = DateTime.now();
      final userId = (storedUsers.length + 2).toString(); // Start from 2 (admin is 1)

      final user = AppUser(
        id: userId,
        email: email,
        fullName: displayName ?? '',
        role: 'staff',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      // Store user data
      final userData = {
        'id': user.id,
        'email': user.email,
        'fullName': user.fullName,
        'role': user.role,
        'isActive': user.isActive,
        'password': _hashPassword(password),
        'createdAt': user.createdAt.millisecondsSinceEpoch,
        'updatedAt': user.updatedAt.millisecondsSinceEpoch,
      };

      storedUsers.add(jsonEncode(userData));
      await prefs.setStringList('users', storedUsers);

      _currentUser = user;

      // Save current user to preferences
      await prefs.setString('current_user_id', user.id);
      await prefs.setString('user_data', jsonEncode(userData));

      _authStateController.add(_currentUser);
      return user;
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('An unexpected error occurred. Please try again.');
    }
  }

  // Sign in with Google (placeholder)
  Future<AppUser?> signInWithGoogle() async {
    throw AuthException('Google Sign In not implemented yet');
  }

  // Sign out
  Future<void> signOut() async {
    try {
      _currentUser = null;

      // Clear saved user from preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_user_id');
      await prefs.remove('user_data');

      _authStateController.add(null);
    } catch (e) {
      throw AuthException('Failed to sign out. Please try again.');
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      if (_currentUser == null) {
        throw AuthException('No user is currently signed in.');
      }

      final db = await _databaseHelper.database;
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };

      if (displayName != null) {
        updates['full_name'] = displayName;
      }

      await db.update(
        'users',
        updates,
        where: 'id = ?',
        whereArgs: [int.tryParse(_currentUser!.id)],
      );

      // Update current user
      _currentUser = _currentUser!.copyWith(
        fullName: displayName ?? _currentUser!.fullName,
        updatedAt: DateTime.now(),
      );

      _authStateController.add(_currentUser);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Failed to update profile. Please try again.');
    }
  }

  // Update user password
  Future<void> updatePassword(String newPassword) async {
    try {
      if (_currentUser == null) {
        throw AuthException('No user is currently signed in.');
      }

      if (newPassword.length < 6) {
        throw AuthException('Password must be at least 6 characters long.');
      }

      final db = await _databaseHelper.database;
      final hashedPassword = _hashPassword(newPassword);

      await db.update(
        'users',
        {
          'password_hash': hashedPassword,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [int.tryParse(_currentUser!.id)],
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Failed to update password. Please try again.');
    }
  }

  // Re-authenticate user (for sensitive operations)
  Future<void> reauthenticateWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      if (_currentUser == null) {
        throw AuthException('No user is currently signed in.');
      }

      final db = await _databaseHelper.database;
      final hashedPassword = _hashPassword(password);

      final List<Map<String, dynamic>> users = await db.query(
        'users',
        where: 'id = ? AND email = ? AND password_hash = ?',
        whereArgs: [int.tryParse(_currentUser!.id), email, hashedPassword],
        limit: 1,
      );

      if (users.isEmpty) {
        throw AuthException('Invalid credentials for re-authentication.');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Failed to re-authenticate. Please try again.');
    }
  }

  // Delete user account
  Future<void> deleteUser() async {
    try {
      if (_currentUser == null) {
        throw AuthException('No user is currently signed in.');
      }

      final db = await _databaseHelper.database;

      // Soft delete - mark as inactive
      await db.update(
        'users',
        {
          'is_active': 0,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [int.tryParse(_currentUser!.id)],
      );

      await signOut();
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Failed to delete account. Please try again.');
    }
  }

  // Get user by ID
  Future<AppUser?> _getUserById(String id) async {
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> users = await db.query(
        'users',
        where: 'id = ? AND is_active = ?',
        whereArgs: [int.tryParse(id), 1],
        limit: 1,
      );

      if (users.isNotEmpty) {
        return AppUser.fromMap(users.first);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Hash password
  String _hashPassword(String password) {
    final bytes = utf8.encode(password + '_salt'); // Add salt for security
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Dispose
  void dispose() {
    _authStateController.close();
  }
}

// Custom exception class for authentication errors
class AuthException implements Exception {
  final String message;

  AuthException(this.message);

  @override
  String toString() => message;
}