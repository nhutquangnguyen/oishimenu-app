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
      QuickActionItem(
        icon: Icons.table_restaurant_outlined,
        title: 'Tables',
        subtitle: 'Manage seating',
        color: Colors.blue[600]!,
        onTap: () => context.go('/tables'),
      ),
      QuickActionItem(
        icon: Icons.group_outlined,
        title: 'Staff',
        subtitle: 'Manage team',
        color: Colors.indigo[600]!,
        onTap: () => context.go('/staff'),
      ),
      QuickActionItem(
        icon: Icons.receipt_long_outlined,
        title: 'Reports',
        subtitle: 'View reports',
        color: Colors.teal[600]!,
        onTap: () => context.go('/reports'),
      ),
      QuickActionItem(
        icon: Icons.kitchen_outlined,
        title: 'Kitchen',
        subtitle: 'Kitchen display',
        color: Colors.red[600]!,
        onTap: () => context.go('/kitchen'),
      ),
      QuickActionItem(
        icon: Icons.people_outline,
        title: 'Customers',
        subtitle: 'Customer data',
        color: Colors.pink[600]!,
        onTap: () => context.go('/customers'),
      ),
      QuickActionItem(
        icon: Icons.event_seat_outlined,
        title: 'Reservations',
        subtitle: 'Book tables',
        color: Colors.brown[600]!,
        onTap: () => context.go('/reservations'),
      ),
      QuickActionItem(
        icon: Icons.print_outlined,
        title: 'Print',
        subtitle: 'Print receipts',
        color: Colors.grey[600]!,
        onTap: () {
          // Show print options
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Print options')),
          );
        },
      ),
      QuickActionItem(
        icon: Icons.settings_outlined,
        title: 'Settings',
        subtitle: 'App settings',
        color: Colors.blueGrey[600]!,
        onTap: () => context.go('/settings'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use more columns for compact icon-only design
        final crossAxisCount = constraints.maxWidth < 400 ? 4 : constraints.maxWidth < 600 ? 6 : 8;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85, // Slightly taller to accommodate text
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
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: action.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
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
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    action.icon,
                    color: action.color,
                    size: 24,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    action.title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10,
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