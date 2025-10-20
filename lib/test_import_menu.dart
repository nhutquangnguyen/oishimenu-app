import 'package:flutter/material.dart';
import 'services/menu_import_service.dart';

void main() {
  runApp(const MenuImportTestApp());
}

class MenuImportTestApp extends StatelessWidget {
  const MenuImportTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Menu Import Test',
      home: const MenuImportPage(),
    );
  }
}

class MenuImportPage extends StatefulWidget {
  const MenuImportPage({super.key});

  @override
  State<MenuImportPage> createState() => _MenuImportPageState();
}

class _MenuImportPageState extends State<MenuImportPage> {
  final MenuImportService _importService = MenuImportService();
  bool _isImporting = false;
  String _importResult = '';

  Future<void> _runImport() async {
    setState(() {
      _isImporting = true;
      _importResult = 'Starting import...';
    });

    try {
      const assetPath = 'assets/menu-export.json';

      setState(() {
        _importResult = 'Reading asset: $assetPath';
      });

      final result = await _importService.importFromAsset(assetPath);

      setState(() {
        _importResult = result.toString();
        _isImporting = false;
      });

      print('Import completed: ${result.success}');
      print(result.toString());

    } catch (e) {
      setState(() {
        _importResult = 'Import failed: $e';
        _isImporting = false;
      });
      print('Import error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Import Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isImporting ? null : _runImport,
              child: _isImporting
                ? const CircularProgressIndicator()
                : const Text('Import Menu Data'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _importResult.isEmpty ? 'No import results yet.' : _importResult,
                    style: const TextStyle(fontFamily: 'monospace'),
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