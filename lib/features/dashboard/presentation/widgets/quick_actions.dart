import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_localizations.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      QuickActionItem(
        icon: Icons.point_of_sale_outlined,
        title: AppLocalizations.pos,
        subtitle: AppLocalizations.startPosOrder,
        color: Theme.of(context).colorScheme.primary,
        onTap: () => context.go('/pos'),
      ),
      QuickActionItem(
        icon: Icons.restaurant_menu_outlined,
        title: AppLocalizations.menu,
        subtitle: AppLocalizations.manageItems,
        color: Colors.green[600]!,
        onTap: () => context.go('/menu'),
      ),
      QuickActionItem(
        icon: Icons.inventory_2_outlined,
        title: AppLocalizations.inventory,
        subtitle: AppLocalizations.checkStock,
        color: Colors.orange[600]!,
        onTap: () => context.go('/inventory'),
      ),
      QuickActionItem(
        icon: Icons.account_balance_outlined,
        title: AppLocalizations.tr('finance') != 'finance'
            ? AppLocalizations.tr('finance')
            : 'Finance',
        subtitle: AppLocalizations.tr('financial_reports') != 'financial_reports'
            ? AppLocalizations.tr('financial_reports')
            : 'Financial Reports',
        color: Colors.purple[600]!,
        onTap: () => context.go('/analytics'),
      ),
      QuickActionItem(
        icon: Icons.group_outlined,
        title: AppLocalizations.staffAction,
        subtitle: AppLocalizations.manageTeam,
        color: Colors.indigo[600]!,
        onTap: () => context.go('/employees'),
      ),
      QuickActionItem(
        icon: Icons.settings_outlined,
        title: AppLocalizations.settings,
        subtitle: AppLocalizations.appSettings,
        color: Colors.blueGrey[600]!,
        onTap: () => context.go('/settings'),
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: actions.map((action) =>
          Container(
            width: 60,
            margin: const EdgeInsets.only(right: 6),
            child: _QuickActionCard(action: action),
          ),
        ).toList(),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final QuickActionItem action;

  const _QuickActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: action.onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  action.color.withOpacity(0.08),
                  action.color.withOpacity(0.03),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(3.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    action.icon,
                    color: action.color,
                    size: 20,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    action.title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class QuickActionItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  QuickActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}