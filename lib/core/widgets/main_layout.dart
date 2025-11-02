import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../models/order.dart';
import '../providers/supabase_providers.dart';

// 🚀 OPTIMIZED: Provider for active orders count with smart app lifecycle awareness
// StateNotifier for active orders count with immediate updates
class ActiveOrdersCountNotifier extends StateNotifier<AsyncValue<int>> {
  ActiveOrdersCountNotifier(this.ref) : super(const AsyncValue.loading()) {
    _initialize();
  }

  final Ref ref;
  Timer? _timer;

  Future<void> _initialize() async {
    await refresh();
    _startPeriodicRefresh();
  }

  void _startPeriodicRefresh() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => refresh());
  }

  Future<void> refresh() async {
    try {
      final orderService = ref.read(supabaseOrderServiceProvider);
      final allOrders = await orderService.getOrders();
      final activeOrders = allOrders.where((order) =>
        order.status != OrderStatus.delivered &&
        order.status != OrderStatus.cancelled
      ).toList();
      state = AsyncValue.data(activeOrders.length);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // Immediate updates for order operations
  void incrementCount() {
    final currentValue = state.valueOrNull ?? 0;
    final newValue = currentValue + 1;
    state = AsyncValue.data(newValue);
  }

  void decrementCount() {
    final currentValue = state.valueOrNull ?? 0;
    if (currentValue > 0) {
      final newValue = currentValue - 1;
      state = AsyncValue.data(newValue);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final activeOrdersCountProvider = StateNotifierProvider<ActiveOrdersCountNotifier, AsyncValue<int>>((ref) {
  return ActiveOrdersCountNotifier(ref);
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
  List<NavigationItem> get _primaryNavigationItems => [
    NavigationItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'navigation.home'.tr(),
      route: '/dashboard',
    ),
    NavigationItem(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      label: 'navigation.orders'.tr(),
      route: '/orders',
    ),
    NavigationItem(
      icon: Icons.add_shopping_cart_outlined,
      selectedIcon: Icons.add_shopping_cart,
      label: 'navigation.pos'.tr(),
      route: '/pos',
    ),
    NavigationItem(
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet,
      label: 'navigation.finance'.tr(),
      route: '/finance',
    ),
    NavigationItem(
      icon: Icons.restaurant_menu_outlined,
      selectedIcon: Icons.restaurant_menu,
      label: 'navigation.menu'.tr(),
      route: '/menu',
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
    }
  }


  String _getPageTitle() {
    final location = GoRouterState.of(context).fullPath;

    // Check primary navigation
    final primaryItem = _primaryNavigationItems.firstWhere(
      (item) => item.route == location,
      orElse: () => _primaryNavigationItems[0],
    );

    return primaryItem.label;
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
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.push('/settings');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
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
            return NavigationDestination(
              icon: Consumer(
                builder: (context, ref, child) {
                  final activeOrdersCount = ref.watch(activeOrdersCountProvider);
                  final count = activeOrdersCount.when(
                    data: (count) => count,
                    loading: () => 0,
                    error: (_, __) => 0,
                  );

                  return Badge(
                    isLabelVisible: count > 0,
                    label: Text('$count'),
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                    child: Icon(item.icon),
                  );
                },
              ),
              selectedIcon: Consumer(
                builder: (context, ref, child) {
                  final activeOrdersCount = ref.watch(activeOrdersCountProvider);
                  final count = activeOrdersCount.when(
                    data: (count) => count,
                    loading: () => 0,
                    error: (_, __) => 0,
                  );

                  return Badge(
                    isLabelVisible: count > 0,
                    label: Text('$count'),
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                    child: Icon(item.selectedIcon),
                  );
                },
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

