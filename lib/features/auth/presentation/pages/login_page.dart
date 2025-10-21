import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_button.dart';
import '../widgets/social_auth_button.dart';
import '../../../../core/localization/app_localizations.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    ref.read(authLoadingProvider.notifier).state = true;
    ref.read(authErrorProvider.notifier).state = null;

    try {
      await ref.read(authServiceProvider).signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        context.go('/dashboard');
      }
    } on AuthException catch (e) {
      ref.read(authErrorProvider.notifier).state = e.message;
    } catch (e) {
      ref.read(authErrorProvider.notifier).state = AppLocalizations.error;
    } finally {
      ref.read(authLoadingProvider.notifier).state = false;
    }
  }

  Future<void> _signInWithGoogle() async {
    ref.read(authLoadingProvider.notifier).state = true;
    ref.read(authErrorProvider.notifier).state = null;

    try {
      await ref.read(authServiceProvider).signInWithGoogle();

      if (mounted) {
        context.go('/dashboard');
      }
    } on AuthException catch (e) {
      ref.read(authErrorProvider.notifier).state = e.message;
    } catch (e) {
      ref.read(authErrorProvider.notifier).state = AppLocalizations.failedGoogleSignin;
    } finally {
      ref.read(authLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authLoadingProvider);
    final authError = ref.watch(authErrorProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),

                // Logo and title
                Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF6d28d9), Color(0xFF7c3aed)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.restaurant,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'OishiMenu',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        background: Paint()
                          ..shader = const LinearGradient(
                            colors: [Color(0xFF6d28d9), Color(0xFF7c3aed)],
                          ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.restaurantManagementSystem,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 60),

                // Welcome text
                Text(
                  AppLocalizations.welcomeBack,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.signInToContinue,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),

                const SizedBox(height: 32),

                // Error message
                if (authError != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            authError,
                            style: TextStyle(color: Colors.red[700]),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Email field
                AuthTextField(
                  controller: _emailController,
                  label: AppLocalizations.email,
                  hintText: AppLocalizations.enterEmail,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return AppLocalizations.pleaseEnterEmail;
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return AppLocalizations.pleaseEnterValidEmail;
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Password field
                AuthTextField(
                  controller: _passwordController,
                  label: AppLocalizations.password,
                  hintText: AppLocalizations.enterPassword,
                  obscureText: _obscurePassword,
                  prefixIcon: Icons.lock_outlined,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return AppLocalizations.pleaseEnterPassword;
                    }
                    if (value.length < 6) {
                      return AppLocalizations.passwordMin6Chars;
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 8),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // Navigate to forgot password
                    },
                    child: Text(AppLocalizations.forgotPassword),
                  ),
                ),

                const SizedBox(height: 24),

                // Sign in button
                AuthButton(
                  text: AppLocalizations.signIn,
                  onPressed: isLoading ? null : _signIn,
                  isLoading: isLoading,
                ),

                const SizedBox(height: 24),

                // Divider
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        AppLocalizations.orContinueWith,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),

                const SizedBox(height: 24),

                // Google sign in
                SocialAuthButton(
                  text: AppLocalizations.continueWithGoogle,
                  icon: Icons.login, // Replace with actual Google icon
                  onPressed: isLoading ? null : _signInWithGoogle,
                ),

                const SizedBox(height: 32),

                // Sign up link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppLocalizations.dontHaveAccount,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () => context.go('/signup'),
                      child: Text(AppLocalizations.signUp),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}