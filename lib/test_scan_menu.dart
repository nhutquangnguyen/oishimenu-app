import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/router/app_router.dart';

void main() {
  runApp(const ProviderScope(child: ScanMenuTestApp()));
}

class ScanMenuTestApp extends ConsumerWidget {
  const ScanMenuTestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Scan Menu Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}

class ScanMenuTestPage extends StatelessWidget {
  const ScanMenuTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Menu Test'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Scan Menu Feature Integration Test',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),

            // Direct scan page test
            ElevatedButton.icon(
              onPressed: () => context.push('/menu/scan'),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Test Scan Menu Page'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),

            const SizedBox(height: 16),

            // Test via menu page
            ElevatedButton.icon(
              onPressed: () => context.push('/menu'),
              icon: const Icon(Icons.restaurant_menu),
              label: const Text('Test via Menu Page'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),

            const SizedBox(height: 32),

            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Test Instructions:\n'
                '1. Click "Test Scan Menu Page" to open the scanner directly\n'
                '2. Test all 4 scan methods (QR, Barcode, Photo, Document)\n'
                '3. Test manual input with Vietnamese menu data\n'
                '4. Try importing individual items and bulk import\n'
                '5. Click "Test via Menu Page" to test the scan button integration',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[300]!),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      const Text(
                        'Sample Data for Testing',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Phở Bò - 65000\n'
                    'Bún Chả - 55000\n'
                    'Bánh Mì - 25000\n'
                    'Chả Cá - 85000\n'
                    'Cơm Tấm - 45000',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}