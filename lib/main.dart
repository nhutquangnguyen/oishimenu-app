import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/config/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/constants/app_constants.dart';
import 'features/auth/services/auth_service.dart';
import 'features/auth/providers/auth_provider.dart';
import 'services/sample_data_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize auth service
  final authService = AuthService();
  await authService.initialize();

  // Initialize sample data (for desktop/mobile platforms)
  try {
    final sampleDataService = SampleDataService();
    await sampleDataService.initializeSampleData();
  } catch (e) {
    print('Sample data initialization failed (expected on web): $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
      ],
      child: const OishiMenuApp(),
    ),
  );
}

class OishiMenuApp extends ConsumerWidget {
  const OishiMenuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}