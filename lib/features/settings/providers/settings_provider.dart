import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:hive/hive.dart';

/// Enum for supported languages
enum AppLanguage {
  vietnamese('vi', 'VN', 'Tiếng Việt'),
  english('en', 'US', 'English');

  const AppLanguage(this.languageCode, this.countryCode, this.displayName);

  final String languageCode;
  final String countryCode;
  final String displayName;

  Locale get locale => Locale(languageCode);

  static AppLanguage fromLocale(Locale locale) {
    for (final language in AppLanguage.values) {
      if (language.languageCode == locale.languageCode) {
        return language;
      }
    }
    return AppLanguage.vietnamese; // Default fallback
  }
}

/// Settings model class
class AppSettings {
  final AppLanguage language;
  final ThemeMode themeMode;

  const AppSettings({
    required this.language,
    required this.themeMode,
  });

  AppSettings copyWith({
    AppLanguage? language,
    ThemeMode? themeMode,
  }) {
    return AppSettings(
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'language': '${language.languageCode}_${language.countryCode}',
      'themeMode': themeMode.name,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    final languageStr = map['language'] as String? ?? 'vi_VN';
    final parts = languageStr.split('_');
    // Only use language code, ignore country code to match supported locales
    final locale = Locale(parts[0]);

    return AppSettings(
      language: AppLanguage.fromLocale(locale),
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == map['themeMode'],
        orElse: () => ThemeMode.light,
      ),
    );
  }
}

/// Settings service for persistence
class SettingsService {
  static const String _boxName = 'app_settings';
  static const String _settingsKey = 'user_settings';

  Box<dynamic>? _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  Future<AppSettings> loadSettings() async {
    if (_box == null) await init();

    final settingsMap = _box!.get(_settingsKey) as Map<dynamic, dynamic>?;
    if (settingsMap == null) {
      // Return default settings if none exist
      return const AppSettings(
        language: AppLanguage.vietnamese,
        themeMode: ThemeMode.light,
      );
    }

    return AppSettings.fromMap(Map<String, dynamic>.from(settingsMap));
  }

  Future<void> saveSettings(AppSettings settings) async {
    if (_box == null) await init();
    await _box!.put(_settingsKey, settings.toMap());
  }
}

/// Settings provider
final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

/// Current settings state provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final service = ref.watch(settingsServiceProvider);
  return SettingsNotifier(service);
});

/// Settings notifier class
class SettingsNotifier extends StateNotifier<AppSettings> {
  final SettingsService _service;

  SettingsNotifier(this._service) : super(const AppSettings(
    language: AppLanguage.vietnamese,
    themeMode: ThemeMode.light,
  )) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _service.loadSettings();
      state = settings;
    } catch (e) {
      // Keep default settings if loading fails
      print('Failed to load settings: $e');
    }
  }

  /// Initialize language on app startup
  Future<void> initializeLanguage(BuildContext context) async {
    try {
      final settings = await _service.loadSettings();
      state = settings;

      // Apply the saved language to EasyLocalization
      switch (settings.language) {
        case AppLanguage.vietnamese:
          await context.setLocale(const Locale('vi'));
          break;
        case AppLanguage.english:
          await context.setLocale(const Locale('en'));
          break;
      }
    } catch (e) {
      print('Failed to initialize language: $e');
    }
  }

  Future<void> updateLanguage(AppLanguage language, BuildContext context) async {
    try {
      // Update the app locale using easy_localization FIRST
      switch (language) {
        case AppLanguage.vietnamese:
          await context.setLocale(const Locale('vi'));
          break;
        case AppLanguage.english:
          await context.setLocale(const Locale('en'));
          break;
      }

      // Then update and save the state
      state = state.copyWith(language: language);
      await _service.saveSettings(state);
    } catch (e) {
      print('Failed to update language: $e');
    }
  }

  Future<void> updateThemeMode(ThemeMode themeMode) async {
    try {
      state = state.copyWith(themeMode: themeMode);
      await _service.saveSettings(state);
    } catch (e) {
      print('Failed to update theme mode: $e');
    }
  }
}

/// Provider for current language
final currentLanguageProvider = Provider<AppLanguage>((ref) {
  return ref.watch(settingsProvider.select((settings) => settings.language));
});

/// Provider for current theme mode
final currentThemeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(settingsProvider.select((settings) => settings.themeMode));
});