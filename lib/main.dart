import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'core/config/app_theme.dart';
import 'core/config/supabase_config.dart';
import 'core/router/app_router.dart';
import 'core/constants/app_constants.dart';
import 'core/services/deep_link_service.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/settings/providers/settings_provider.dart';
import 'core/providers/supabase_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize EasyLocalization
  await EasyLocalization.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize Supabase
  await SupabaseConfig.initialize();

  // Initialize Deep Link Service for email confirmations
  await DeepLinkService.initialize();

  // Supabase auth is automatically initialized through SupabaseConfig.initialize()

  // Sample data initialization removed - each user manages their own menu data

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('vi'), // Vietnamese - Default
        Locale('en'), // English
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('vi'),
      startLocale: const Locale('vi'), // Set Vietnamese as default
      child: ProviderScope(
        overrides: [
          authServiceProvider.overrideWith((ref) => SupabaseAuthServiceAdapter()),
        ],
        child: const OishiMenuApp(),
      ),
    ),
  );
}

class OishiMenuApp extends ConsumerStatefulWidget {
  const OishiMenuApp({super.key});

  @override
  ConsumerState<OishiMenuApp> createState() => _OishiMenuAppState();
}

class _OishiMenuAppState extends ConsumerState<OishiMenuApp> {
  @override
  void initState() {
    super.initState();
    // Initialize language settings after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(settingsProvider.notifier).initializeLanguage(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(currentThemeModeProvider);
    final currentLanguage = ref.watch(currentLanguageProvider);

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
      locale: currentLanguage.locale,
    );
  }
}