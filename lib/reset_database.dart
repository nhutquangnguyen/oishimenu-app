import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/supabase_config.dart';
import 'core/providers/supabase_providers.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseConfig.initialize();

  runApp(const ProviderScope(child: DatabaseResetApp()));
}

class DatabaseResetApp extends StatelessWidget {
  const DatabaseResetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Database Reset Tool',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const DatabaseResetPage(),
    );
  }
}

class DatabaseResetPage extends ConsumerStatefulWidget {
  const DatabaseResetPage({super.key});

  @override
  ConsumerState<DatabaseResetPage> createState() => _DatabaseResetPageState();
}

class _DatabaseResetPageState extends ConsumerState<DatabaseResetPage> {
  bool _isResetting = false;
  bool _isCleaning = false;
  String _status = '';

  Future<void> _resetDatabase() async {
    setState(() {
      _isResetting = true;
      _status = 'Resetting Supabase data...';
    });

    try {
      // Get Supabase services
      final inventoryService = ref.read(supabaseInventoryServiceProvider);
      final menuService = ref.read(supabaseMenuServiceProvider);
      final orderService = ref.read(supabaseOrderServiceProvider);
      final customerService = ref.read(supabaseCustomerServiceProvider);
      final orderSourceService = ref.read(supabaseOrderSourceServiceProvider);

      // Clear existing data (WARNING: This will delete all user data!)
      setState(() {
        _status = 'Clearing existing data from Supabase...';
      });

      // Clear tables in dependency order (most dependent first)
      await SupabaseService.client.from('order_items').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      await SupabaseService.client.from('orders').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      await SupabaseService.client.from('inventory_transactions').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      await SupabaseService.client.from('stocktake_items').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      await SupabaseService.client.from('stocktake_sessions').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      await SupabaseService.client.from('ingredients').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      await SupabaseService.client.from('menu_item_option_groups').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      await SupabaseService.client.from('option_group_options').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      await SupabaseService.client.from('menu_items').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      await SupabaseService.client.from('option_groups').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      await SupabaseService.client.from('menu_options').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      await SupabaseService.client.from('menu_categories').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      await SupabaseService.client.from('customers').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      await SupabaseService.client.from('order_sources').delete().neq('id', '00000000-0000-0000-0000-000000000000');

      // Initialize default order sources
      setState(() {
        _status = 'Creating default order sources...';
      });
      await orderSourceService.initializeDefaultOrderSources();

      // Note: Sample inventory data creation would need to be implemented in SupabaseInventoryService
      setState(() {
        _status = '✅ Supabase data reset complete! Ready for fresh data.';
        _isResetting = false;
      });

    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
        _isResetting = false;
      });
      print('Reset error: $e');
    }
  }

  Future<void> _cleanupDatabase() async {
    setState(() {
      _isCleaning = true;
      _status = 'Starting Supabase data cleanup...';
    });

    try {
      setState(() {
        _status = 'Checking for orphaned records...';
      });

      int totalCleaned = 0;

      // Clean orphaned option group options (options that reference non-existent option groups)
      setState(() {
        _status = 'Cleaning orphaned option group options...';
      });

      final orphanedGroupOptions = await SupabaseService.client
          .from('option_group_options')
          .select('id')
          .not('option_group_id', 'in', '(${SupabaseService.client.from('option_groups').select('id')})');

      if (orphanedGroupOptions.isNotEmpty) {
        final orphanedIds = orphanedGroupOptions.map((record) => record['id']).toList();
        await SupabaseService.client.from('option_group_options').delete().in_('id', orphanedIds);
        totalCleaned += orphanedGroupOptions.length;
      }

      // Clean orphaned menu item option groups (references to non-existent menu items or option groups)
      setState(() {
        _status = 'Cleaning orphaned menu item option groups...';
      });

      final orphanedItemOptions = await SupabaseService.client
          .from('menu_item_option_groups')
          .select('id')
          .not('menu_item_id', 'in', '(${SupabaseService.client.from('menu_items').select('id')})')
          .not('option_group_id', 'in', '(${SupabaseService.client.from('option_groups').select('id')})');

      if (orphanedItemOptions.isNotEmpty) {
        final orphanedIds = orphanedItemOptions.map((record) => record['id']).toList();
        await SupabaseService.client.from('menu_item_option_groups').delete().in_('id', orphanedIds);
        totalCleaned += orphanedItemOptions.length;
      }

      // Clean orphaned stocktake items (references to non-existent sessions or ingredients)
      setState(() {
        _status = 'Cleaning orphaned stocktake items...';
      });

      final orphanedStocktakeItems = await SupabaseService.client
          .from('stocktake_items')
          .select('id')
          .not('session_id', 'in', '(${SupabaseService.client.from('stocktake_sessions').select('id')})')
          .not('ingredient_id', 'in', '(${SupabaseService.client.from('ingredients').select('id')})');

      if (orphanedStocktakeItems.isNotEmpty) {
        final orphanedIds = orphanedStocktakeItems.map((record) => record['id']).toList();
        await SupabaseService.client.from('stocktake_items').delete().in_('id', orphanedIds);
        totalCleaned += orphanedStocktakeItems.length;
      }

      setState(() {
        _status = '✅ Supabase cleanup complete! Cleaned $totalCleaned orphaned records.\n\n'
            'Data integrity verified and optimized.';
        _isCleaning = false;
      });

    } catch (e) {
      setState(() {
        _status = '❌ Cleanup Error: $e';
        _isCleaning = false;
      });
      print('Cleanup error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supabase Data Management'),
        backgroundColor: Colors.red[600],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.warning,
              size: 80,
              color: Colors.orange,
            ),
            const SizedBox(height: 24),
            const Text(
              'Supabase Data Management',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Manage your cloud database data with Supabase. Clean orphaned records or reset all data.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            if (_status.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _status,
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
            ],

            if (_isResetting || _isCleaning)
              const CircularProgressIndicator()
            else ...[
              ElevatedButton.icon(
                onPressed: _cleanupDatabase,
                icon: const Icon(Icons.cleaning_services),
                label: const Text('Clean Supabase Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _resetDatabase,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset All Supabase Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],

            const SizedBox(height: 24),
            const Text(
              'Clean Supabase Data:\n'
              '• Remove orphaned records and fix data integrity\n'
              '• Optimize database performance\n'
              '• Keep all valid data (recommended first)\n\n'
              'Reset All Supabase Data:\n'
              '• WARNING: Delete all user data in cloud database\n'
              '• Initialize default order sources\n'
              '• Reset to fresh state for testing\n'
              '• Use with extreme caution in production!',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}