import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      QuickActionItem(
        icon: Icons.point_of_sale_outlined,
        title: 'New Order',
        subtitle: 'Start POS order',
        color: Theme.of(context).colorScheme.primary,
        onTap: () => context.go('/pos'),
      ),
      QuickActionItem(
        icon: Icons.restaurant_menu_outlined,
        title: 'Menu',
        subtitle: 'Manage items',
        color: Colors.green[600]!,
        onTap: () => context.go('/menu'),
      ),
      QuickActionItem(
        icon: Icons.inventory_2_outlined,
        title: 'Inventory',
        subtitle: 'Check stock',
        color: Colors.orange[600]!,
        onTap: () => context.go('/inventory'),
      ),
      QuickActionItem(
        icon: Icons.analytics_outlined,
        title: 'Analytics',
        subtitle: 'View insights',
        color: Colors.purple[600]!,
        onTap: () => context.go('/analytics'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // On narrow screens, show 2 columns; on wider screens, show 4 columns
        final crossAxisCount = constraints.maxWidth < 600 ? 2 : 4;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: crossAxisCount == 2 ? 1.3 : 0.85,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return _QuickActionCard(action: action);
          },
        );
      },
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
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: action.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  action.color.withOpacity(0.05),
                  action.color.withOpacity(0.02),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: action.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      action.icon,
                      color: action.color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: Text(
                      action.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: Text(
                      action.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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