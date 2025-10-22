import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/database_helper.dart';
import 'services/inventory_service.dart';

void main() {
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

class DatabaseResetPage extends StatefulWidget {
  const DatabaseResetPage({super.key});

  @override
  State<DatabaseResetPage> createState() => _DatabaseResetPageState();
}

class _DatabaseResetPageState extends State<DatabaseResetPage> {
  bool _isResetting = false;
  String _status = '';

  Future<void> _resetDatabase() async {
    setState(() {
      _isResetting = true;
      _status = 'Resetting database...';
    });

    try {
      final dbHelper = DatabaseHelper();

      // Delete the existing database
      setState(() {
        _status = 'Deleting old database...';
      });
      await dbHelper.deleteDatabase();

      // Create fresh database with new schema
      setState(() {
        _status = 'Creating fresh database with inventory tables...';
      });
      final db = await dbHelper.database;

      // Verify inventory tables exist
      setState(() {
        _status = 'Verifying inventory tables...';
      });

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '%stock%' OR name LIKE '%ingredient%'"
      );

      print('📊 Database tables found:');
      for (final table in tables) {
        print('  - ${table['name']}');
      }

      // Create sample inventory data
      setState(() {
        _status = 'Creating sample Vietnamese inventory data...';
      });

      final inventoryService = InventoryService();
      await inventoryService.createSampleInventoryData();

      setState(() {
        _status = '✅ Database reset complete! Inventory system ready.';
        _isResetting = false;
      });

    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
        _isResetting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Reset Tool'),
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
              'Database Reset Required',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'To see the new inventory functionality, we need to reset the database to version 4 with the new stocktake tables.',
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

            if (_isResetting)
              const CircularProgressIndicator()
            else
              ElevatedButton.icon(
                onPressed: _resetDatabase,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset Database & Create Inventory'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),

            const SizedBox(height: 24),
            const Text(
              'This will:\n'
              '• Delete existing database\n'
              '• Create fresh schema with inventory tables\n'
              '• Add sample Vietnamese restaurant ingredients\n'
              '• Enable stocktake functionality',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}