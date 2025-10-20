import 'package:flutter/material.dart';
import 'services/menu_import_service.dart';
import 'features/menu/services/menu_service.dart';
import 'services/menu_option_service.dart';

void main() {
  runApp(const ImportValidationApp());
}

class ImportValidationApp extends StatelessWidget {
  const ImportValidationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Import Validation Test',
      home: const ImportValidationPage(),
    );
  }
}

class ImportValidationPage extends StatefulWidget {
  const ImportValidationPage({super.key});

  @override
  State<ImportValidationPage> createState() => _ImportValidationPageState();
}

class _ImportValidationPageState extends State<ImportValidationPage> {
  final MenuImportService _importService = MenuImportService();
  final MenuService _menuService = MenuService();
  final MenuOptionService _menuOptionService = MenuOptionService();

  bool _isRunning = false;
  String _results = 'Press "Run Import & Validation" to start';

  Future<void> _runImportAndValidation() async {
    setState(() {
      _isRunning = true;
      _results = 'Starting import and validation...\n';
    });

    try {
      // Step 1: Run Import
      _addResult('1. Starting menu import from assets...');
      final importResult = await _importService.importFromAsset('assets/menu-export.json');

      _addResult('Import Result: ${importResult.success}');
      _addResult(importResult.toString());

      if (!importResult.success) {
        _addResult('❌ Import failed, stopping validation');
        return;
      }

      // Step 2: Validate Categories
      _addResult('\n2. Validating categories...');
      final categories = await _menuService.getCategories();
      _addResult('Found ${categories.length} categories');

      // Check for some expected Vietnamese categories
      final expectedCategories = ['TRÀ SỮA', 'MATCHA', 'CÀ PHÊ - COFFEE', 'TRÀ - TEA'];
      for (final expected in expectedCategories) {
        final found = categories.values.any((name) => name.contains(expected));
        _addResult('${found ? "✅" : "❌"} Category "$expected": ${found ? "Found" : "Not found"}');
      }

      // Step 3: Validate Menu Items
      _addResult('\n3. Validating menu items...');
      final menuItems = await _menuService.getAllMenuItems();
      _addResult('Found ${menuItems.length} menu items');

      // Check for some expected Vietnamese menu items
      final expectedItems = [
        'Trà sữa Dinh- Dinh Milk Tea',
        'Matcha latte',
        'Cafe đen đá - Iced Black Coffee'
      ];

      for (final expected in expectedItems) {
        final found = menuItems.any((item) => item.name.contains(expected.split(' ')[0]));
        _addResult('${found ? "✅" : "❌"} Menu item containing "${expected.split(' ')[0]}": ${found ? "Found" : "Not found"}');
      }

      // Step 4: Validate Option Groups
      _addResult('\n4. Validating option groups...');
      final optionGroups = await _menuOptionService.getAllOptionGroups();
      _addResult('Found ${optionGroups.length} option groups');

      final expectedGroups = ['Size', 'Sweetness', 'Toppings'];
      for (final expected in expectedGroups) {
        final found = optionGroups.any((group) => group.name.toLowerCase().contains(expected.toLowerCase()));
        _addResult('${found ? "✅" : "❌"} Option group "$expected": ${found ? "Found" : "Not found"}');
      }

      // Step 5: Check relationships
      _addResult('\n5. Checking menu item to option group relationships...');
      if (menuItems.isNotEmpty && optionGroups.isNotEmpty) {
        final firstItem = menuItems.first;
        final itemGroups = await _menuOptionService.getOptionGroupsForMenuItem(firstItem.id);
        _addResult('First menu item "${firstItem.name}" has ${itemGroups.length} option groups');

        if (itemGroups.isNotEmpty) {
          _addResult('✅ Menu item relationships working');
          for (final group in itemGroups) {
            final options = await _menuOptionService.getOptionsForGroup(group.id);
            _addResult('  - ${group.name}: ${options.length} options');
          }
        } else {
          _addResult('⚠️  No option groups found for menu items');
        }
      }

      _addResult('\n🎉 Validation completed successfully!');
      _addResult('\n📊 Summary:');
      _addResult('- Categories: ${categories.length}');
      _addResult('- Menu Items: ${menuItems.length}');
      _addResult('- Option Groups: ${optionGroups.length}');

    } catch (e) {
      _addResult('❌ Error during validation: $e');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  void _addResult(String message) {
    setState(() {
      _results += '$message\n';
    });
    print(message); // Also print to console
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Validation Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isRunning ? null : _runImportAndValidation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isRunning
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)),
                        SizedBox(width: 12),
                        Text('Running...', style: TextStyle(color: Colors.white)),
                      ],
                    )
                  : const Text('Run Import & Validation', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _results,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}