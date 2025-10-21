import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/signup_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/menu/presentation/pages/menu_page.dart';
import '../../features/orders/presentation/pages/orders_page.dart';
import '../../features/pos/presentation/pages/pos_page.dart';
import '../../features/inventory/presentation/pages/inventory_page.dart';
import '../../features/employees/presentation/pages/employees_page.dart';
import '../../features/feedback/presentation/pages/feedback_page.dart';
import '../../features/analytics/presentation/pages/analytics_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/option_groups/pages/option_group_editor_page.dart';
import '../../features/menu/presentation/pages/menu_item_editor_page.dart';
import '../../features/menu/presentation/pages/scan_menu_page.dart';
import '../../test_menu_editor.dart';
import '../../test_scan_menu.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../widgets/main_layout.dart';

// Router provider
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/menu',
    redirect: (context, state) {
      // Check authentication status
      final isLoggedIn = authState.when(
        data: (user) => user != null,
        loading: () => false,
        error: (_, __) => false,
      );

      final isOnAuthPage = state.fullPath == '/login' || state.fullPath == '/signup';
      final isOnTestPage = state.fullPath == '/test' || state.fullPath == '/test-scan';
      final isOnMenuPage = state.fullPath?.startsWith('/menu') == true;

      // Redirect to login if not authenticated and not on auth, test, or menu pages
      if (!isLoggedIn && !isOnAuthPage && !isOnTestPage && !isOnMenuPage) {
        return '/login';
      }

      // Redirect to menu if authenticated and on auth page
      if (isLoggedIn && isOnAuthPage) {
        return '/menu';
      }

      return null; // No redirect needed
    },
    routes: [
      // Test routes
      GoRoute(
        path: '/test',
        builder: (context, state) => const MenuEditorTestPage(),
      ),
      GoRoute(
        path: '/test-scan',
        builder: (context, state) => const ScanMenuTestPage(),
      ),

      // Authentication routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupPage(),
      ),

      // Main app routes with layout
      ShellRoute(
        builder: (context, state, child) => MainLayout(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: '/menu',
            builder: (context, state) => const MenuPage(),
            routes: [
              GoRoute(
                path: 'scan',
                builder: (context, state) => const ScanMenuPage(),
              ),
              GoRoute(
                path: 'option-groups/new',
                builder: (context, state) => const OptionGroupEditorPage(),
              ),
              GoRoute(
                path: 'option-groups/:id/edit',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return OptionGroupEditorPage(optionGroupId: id);
                },
              ),
              GoRoute(
                path: 'items/new',
                builder: (context, state) => const MenuItemEditorPage(),
              ),
              GoRoute(
                path: 'items/:id/edit',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return MenuItemEditorPage(menuItemId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/orders',
            builder: (context, state) => const OrdersPage(),
          ),
          GoRoute(
            path: '/pos',
            builder: (context, state) => const PosPage(),
          ),
          GoRoute(
            path: '/inventory',
            builder: (context, state) => const InventoryPage(),
          ),
          GoRoute(
            path: '/employees',
            builder: (context, state) => const EmployeesPage(),
          ),
          GoRoute(
            path: '/feedback',
            builder: (context, state) => const FeedbackPage(),
          ),
          GoRoute(
            path: '/analytics',
            builder: (context, state) => const AnalyticsPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'The page you are looking for does not exist.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Go to Dashboard'),
            ),
          ],
        ),
      ),
    ),
  );
});

// Route extensions for type safety
extension AppRoutes on GoRouter {
  void goToDashboard() => go('/dashboard');
  void goToMenu() => go('/menu');
  void goToOrders() => go('/orders');
  void goToPos() => go('/pos');
  void goToInventory() => go('/inventory');
  void goToEmployees() => go('/employees');
  void goToFeedback() => go('/feedback');
  void goToAnalytics() => go('/analytics');
  void goToSettings() => go('/settings');
  void goToLogin() => go('/login');
  void goToSignup() => go('/signup');

  // Scan menu route
  void goToScanMenu() => go('/menu/scan');

  // Option group routes
  void goToNewOptionGroup() => go('/menu/option-groups/new');
  void goToEditOptionGroup(String id) => go('/menu/option-groups/$id/edit');

  // Menu item routes
  void goToNewMenuItem() => go('/menu/items/new');
  void goToEditMenuItem(String id) => go('/menu/items/$id/edit');
}