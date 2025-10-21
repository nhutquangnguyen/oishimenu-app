import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'core/config/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/constants/app_constants.dart';
import 'features/auth/services/auth_service.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/settings/providers/settings_provider.dart';
import 'services/sample_data_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize EasyLocalization
  await EasyLocalization.ensureInitialized();

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
    EasyLocalization(
      supportedLocales: const [
        Locale('vi', 'VN'), // Vietnamese (Vietnam) - Default
        Locale('en', 'US'), // English (US)
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('vi', 'VN'),
      startLocale: const Locale('vi', 'VN'), // Set Vietnamese as default
      child: ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
        ],
        child: const OishiMenuApp(),
      ),
    ),
  );
}

class OishiMenuApp extends ConsumerWidget {
  const OishiMenuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(currentThemeModeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,

      // Localization configuration
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}