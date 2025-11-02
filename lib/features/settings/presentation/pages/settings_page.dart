import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../providers/settings_provider.dart';
import 'order_source_management_page.dart';
import '../../../testing/test_results_page.dart';
import '../../../auth/providers/auth_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
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

            // Profile Section
            _buildSectionCard(
              context: context,
              title: AppLocalizations.tr('settings_page.profile'),
              children: [
                Consumer(
                  builder: (context, ref, child) {
                    final user = ref.watch(currentUserProvider);
                    final displayName = ref.watch(userDisplayNameProvider);

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      title: Text(displayName),
                      subtitle: user?.email != null ? Text(user!.email) : null,
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        // Navigate to profile edit page
                        // TODO: Implement profile editing
                      },
                      contentPadding: EdgeInsets.zero,
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Support Section
            _buildSectionCard(
              context: context,
              title: AppLocalizations.tr('settings_page.support'),
              children: [
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: Text(AppLocalizations.tr('settings_page.help_support')),
                  subtitle: const Text('Get help and contact support'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Navigate to help & support page
                    // TODO: Implement help & support
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

            const SizedBox(height: 24),

            // Sign Out Section
            _buildSectionCard(
              context: context,
              title: AppLocalizations.tr('settings_page.account'),
              children: [
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: Text(
                    AppLocalizations.tr('settings_page.sign_out'),
                    style: const TextStyle(color: Colors.red),
                  ),
                  subtitle: const Text('Sign out of your account'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
                  onTap: () async {
                    // Show confirmation dialog
                    final shouldSignOut = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(AppLocalizations.tr('settings_page.sign_out')),
                        content: const Text('Are you sure you want to sign out?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: Text(AppLocalizations.tr('settings_page.sign_out')),
                          ),
                        ],
                      ),
                    );

                    if (shouldSignOut == true) {
                      await ref.read(authServiceProvider).signOut();
                      if (context.mounted) {
                        context.go('/login');
                      }
                    }
                  },
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
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
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
        if (!isSelected && context.mounted) {
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
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
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
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
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
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
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