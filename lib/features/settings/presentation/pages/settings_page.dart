import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../providers/settings_provider.dart';
import 'order_source_management_page.dart';
import '../../../testing/test_results_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(AppLocalizations.settings),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language Section
            _buildSectionCard(
              context: context,
              title: AppLocalizations.tr('settings_page.language'),
              children: [
                _buildLanguageOption(
                  context: context,
                  ref: ref,
                  language: AppLanguage.vietnamese,
                  isSelected: settings.language == AppLanguage.vietnamese,
                ),
                const SizedBox(height: 8),
                _buildLanguageOption(
                  context: context,
                  ref: ref,
                  language: AppLanguage.english,
                  isSelected: settings.language == AppLanguage.english,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Theme Section (Future implementation)
            _buildSectionCard(
              context: context,
              title: AppLocalizations.tr('settings_page.theme'),
              children: [
                _buildThemeOption(
                  context: context,
                  ref: ref,
                  themeMode: ThemeMode.light,
                  title: AppLocalizations.tr('settings_page.light_mode'),
                  icon: Icons.light_mode,
                  isSelected: settings.themeMode == ThemeMode.light,
                ),
                const SizedBox(height: 8),
                _buildThemeOption(
                  context: context,
                  ref: ref,
                  themeMode: ThemeMode.dark,
                  title: AppLocalizations.tr('settings_page.dark_mode'),
                  icon: Icons.dark_mode,
                  isSelected: settings.themeMode == ThemeMode.dark,
                ),
                const SizedBox(height: 8),
                _buildThemeOption(
                  context: context,
                  ref: ref,
                  themeMode: ThemeMode.system,
                  title: AppLocalizations.tr('settings_page.system_mode'),
                  icon: Icons.auto_mode,
                  isSelected: settings.themeMode == ThemeMode.system,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Management Section
            _buildSectionCard(
              context: context,
              title: 'Management',
              children: [
                ListTile(
                  leading: const Icon(Icons.source),
                  title: const Text('Order Sources'),
                  subtitle: const Text('Manage order sources and commissions'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OrderSourceManagementPage(),
                      ),
                    );
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Testing Section
            _buildSectionCard(
              context: context,
              title: 'Testing & Quality Assurance',
              children: [
                ListTile(
                  leading: const Icon(Icons.science, color: Colors.blue),
                  title: const Text('Automated Tests'),
                  subtitle: const Text('Run comprehensive system tests'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TestResultsPage(),
                      ),
                    );
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // App Info Section
            _buildSectionCard(
              context: context,
              title: AppLocalizations.tr('settings_page.app_info'),
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Icon(
                      Icons.restaurant,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  title: Text(AppLocalizations.appName),
                  subtitle: Text('${AppLocalizations.tr('settings_page.version')} 1.0.0'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required WidgetRef ref,
    required AppLanguage language,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () async {
        if (!isSelected) {
          await ref.read(settingsProvider.notifier).updateLanguage(language, context);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                ),
              ),
              child: Center(
                child: Text(
                  language == AppLanguage.vietnamese ? '🇻🇳' : '🇺🇸',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                language.displayName,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required WidgetRef ref,
    required ThemeMode themeMode,
    required String title,
    required IconData icon,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () async {
        if (!isSelected) {
          await ref.read(settingsProvider.notifier).updateThemeMode(themeMode);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}