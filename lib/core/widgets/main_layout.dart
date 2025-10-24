import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../services/order_service.dart';
import '../../models/order.dart';
import '../localization/app_localizations.dart';

// Provider for active orders count
final activeOrdersCountProvider = StreamProvider<int>((ref) async* {
  final orderService = OrderService();

  while (true) {
    try {
      final activeOrders = await orderService.getOrders(status: OrderStatus.pending);
      yield activeOrders.length;
    } catch (e) {
      yield 0;
    }

    // Refresh every 2 seconds for faster updates
    await Future.delayed(const Duration(seconds: 2));
  }
});

class MainLayout extends ConsumerStatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  int _selectedIndex = 0;

  // Main navigation items (5 for mobile-friendly bottom navigation)
  final List<NavigationItem> _primaryNavigationItems = [
    NavigationItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
      route: '/dashboard',
    ),
    NavigationItem(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      label: 'Orders',
      route: '/orders',
    ),
    NavigationItem(
      icon: Icons.add_shopping_cart_outlined,
      selectedIcon: Icons.add_shopping_cart,
      label: 'POS',
      route: '/pos',
    ),
    NavigationItem(
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics,
      label: 'Finance',
      route: '/analytics',
    ),
    NavigationItem(
      icon: Icons.more_horiz,
      selectedIcon: Icons.more_horiz,
      label: 'More',
      route: '/more',
    ),
  ];

  // Secondary navigation items for "More" section
  final List<MoreNavigationItem> _secondaryNavigationItems = [
    MoreNavigationItem(
      icon: Icons.restaurant_menu_outlined,
      label: 'Menu',
      route: '/menu',
      subtitle: 'Manage menu items',
    ),
    MoreNavigationItem(
      icon: Icons.inventory_2_outlined,
      label: 'Inventory',
      route: '/inventory',
      subtitle: 'Stock management',
    ),
    MoreNavigationItem(
      icon: Icons.people_outline,
      label: 'Employees',
      route: '/employees',
      subtitle: 'Staff management',
    ),
    MoreNavigationItem(
      icon: Icons.feedback_outlined,
      label: 'Feedback',
      route: '/feedback',
      subtitle: 'Customer reviews',
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateSelectedIndex();
  }

  void _updateSelectedIndex() {
    final location = GoRouterState.of(context).fullPath;
    final index = _primaryNavigationItems.indexWhere((item) => item.route == location);
    if (index != -1) {
      setState(() {
        _selectedIndex = index;
      });
    } else {
      // Check if it's one of the secondary items (should show "More" as selected)
      final secondaryExists = _secondaryNavigationItems.any((item) => item.route == location);
      if (secondaryExists) {
        setState(() {
          _selectedIndex = 4; // More tab index
        });
      }
    }
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildMoreOptionsSheet(),
    );
  }

  Widget _buildMoreOptionsSheet() {
    final user = ref.watch(currentUserProvider);
    final displayName = ref.watch(userDisplayNameProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
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
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (user?.email != null)
                      Text(
                        user!.email,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Navigation options
          Text(
            AppLocalizations.tr('settings_page.features'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          ..._secondaryNavigationItems.map((item) => _buildMoreOptionTile(item)),

          const Divider(height: 32),

          // Account options
          Text(
            AppLocalizations.tr('settings_page.account'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          _buildAccountOptionTile(
            icon: Icons.person_outline,
            title: AppLocalizations.tr('settings_page.profile'),
            onTap: () {
              Navigator.pop(context);
              // Navigate to profile
            },
          ),
          _buildAccountOptionTile(
            icon: Icons.settings_outlined,
            title: AppLocalizations.settings,
            onTap: () {
              Navigator.pop(context);
              Future.microtask(() {
                if (mounted) context.go('/settings');
              });
            },
          ),
          _buildAccountOptionTile(
            icon: Icons.help_outline,
            title: AppLocalizations.tr('settings_page.help_support'),
            onTap: () {
              Navigator.pop(context);
              // Navigate to help
            },
          ),
          _buildAccountOptionTile(
            icon: Icons.logout,
            title: AppLocalizations.tr('settings_page.sign_out'),
            iconColor: Colors.red,
            textColor: Colors.red,
            onTap: () async {
              Navigator.pop(context);
              await ref.read(authServiceProvider).signOut();
              if (mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMoreOptionTile(MoreNavigationItem item) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          item.icon,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(item.label),
      subtitle: Text(item.subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        Navigator.pop(context);
        Future.microtask(() {
          if (mounted) context.go(item.route);
        });
      },
    );
  }

  Widget _buildAccountOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: TextStyle(color: textColor)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  String _getPageTitle() {
    final location = GoRouterState.of(context).fullPath;

    // Check primary navigation
    final primaryItem = _primaryNavigationItems.firstWhere(
      (item) => item.route == location,
      orElse: () => _primaryNavigationItems[0],
    );

    if (primaryItem.route == location) {
      return primaryItem.label;
    }

    // Check secondary navigation
    final secondaryItem = _secondaryNavigationItems.firstWhere(
      (item) => item.route == location,
      orElse: () => MoreNavigationItem(icon: Icons.home, label: 'Home', route: '/dashboard', subtitle: ''),
    );

    return secondaryItem.label;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getPageTitle()),
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined),
                // Add notification badge if needed
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 8,
                      minHeight: 8,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {
              // Navigate to notifications
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          if (index == 4) { // More tab
            _showMoreOptions();
            return;
          }

          setState(() {
            _selectedIndex = index;
          });
          context.go(_primaryNavigationItems[index].route);
        },
        destinations: _primaryNavigationItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;

          // Orders tab with active orders count badge (index 1)
          if (index == 1) {
            final activeOrdersCount = ref.watch(activeOrdersCountProvider);
            final count = activeOrdersCount.when(
              data: (count) => count,
              loading: () => 0,
              error: (_, __) => 0,
            );

            return NavigationDestination(
              icon: Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                backgroundColor: Colors.red,
                textColor: Colors.white,
                child: Icon(item.icon),
              ),
              selectedIcon: Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                backgroundColor: Colors.red,
                textColor: Colors.white,
                child: Icon(item.selectedIcon),
              ),
              label: item.label,
            );
          }

          // Special highlighting for POS tab (index 2)
          if (index == 2) {
            return NavigationDestination(
              icon: Badge(
                backgroundColor: Theme.of(context).colorScheme.primary,
                smallSize: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    item.icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
              ),
              selectedIcon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.selectedIcon,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 24,
                ),
              ),
              label: item.label,
            );
          }

          // Regular styling for other tabs
          return NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon),
            label: item.label,
          );
        }).toList(),
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;

  NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
  });
}

class MoreNavigationItem {
  final IconData icon;
  final String label;
  final String route;
  final String subtitle;

  MoreNavigationItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.subtitle,
  });
}