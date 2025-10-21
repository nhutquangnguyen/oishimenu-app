import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/router/app_router.dart';

void main() {
  runApp(const ProviderScope(child: MenuEditorTestApp()));
}

class MenuEditorTestApp extends ConsumerWidget {
  const MenuEditorTestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Menu Editor Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}

class MenuEditorTestPage extends StatelessWidget {
  const MenuEditorTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Editor Test'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Menu Item Editor Integration Test',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),

            ElevatedButton.icon(
              onPressed: () => context.push('/menu/items/new'),
              icon: const Icon(Icons.add),
              label: const Text('Test Create New Menu Item'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: () => context.push('/menu/items/1/edit'),
              icon: const Icon(Icons.edit),
              label: const Text('Test Edit Menu Item (ID: 1)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: () => context.push('/menu'),
              icon: const Icon(Icons.restaurant_menu),
              label: const Text('Go to Menu Page'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),

            const SizedBox(height: 32),

            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Test Instructions:\n'
                '1. Click "Test Create New Menu Item" to open the menu item editor\n'
                '2. Fill in the form and save to test creation\n'
                '3. Click "Test Edit Menu Item" to test editing (if item exists)\n'
                '4. Use "Go to Menu Page" to test navigation from menu page',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}