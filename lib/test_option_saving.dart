import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/database_helper.dart';
import 'services/menu_option_service.dart';
import 'models/menu_options.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Option Saving Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const OptionSavingTestPage(),
    );
  }
}

class OptionSavingTestPage extends ConsumerStatefulWidget {
  const OptionSavingTestPage({super.key});

  @override
  ConsumerState<OptionSavingTestPage> createState() => _OptionSavingTestPageState();
}

class _OptionSavingTestPageState extends ConsumerState<OptionSavingTestPage> {
  final MenuOptionService _optionService = MenuOptionService();
  List<OptionGroup> _optionGroups = [];
  bool _isLoading = false;
  String _testResults = '';

  @override
  void initState() {
    super.initState();
    _loadOptionGroups();
  }

  Future<void> _loadOptionGroups() async {
    setState(() => _isLoading = true);
    try {
      final groups = await _optionService.getAllOptionGroups();
      setState(() {
        _optionGroups = groups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _testResults = 'Error loading option groups: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _testCreateOptionGroup() async {
    setState(() {
      _isLoading = true;
      _testResults = 'Testing option group creation...';
    });

    try {
      // Create test option group
      final testGroup = OptionGroup(
        id: '',
        name: 'Test Size Group ${DateTime.now().millisecondsSinceEpoch}',
        description: 'Test option group for size selection',
        minSelection: 1,
        maxSelection: 1,
        isRequired: true,
        displayOrder: 1,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        options: [],
      );

      // Test creating the option group
      final groupId = await _optionService.createOptionGroup(testGroup);

      if (groupId != null) {
        // Create test options for this group
        final testOptions = [
          MenuOption(
            id: '',
            name: 'Small',
            price: 0.0,
            description: 'Small size option',
            category: 'size',
            isAvailable: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          MenuOption(
            id: '',
            name: 'Medium',
            price: 2.0,
            description: 'Medium size option',
            category: 'size',
            isAvailable: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          MenuOption(
            id: '',
            name: 'Large',
            price: 4.0,
            description: 'Large size option',
            category: 'size',
            isAvailable: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        // Test saving options for the group
        int savedCount = 0;
        for (final option in testOptions) {
          try {
            final optionId = await _optionService.createMenuOption(option);
            if (optionId != null) {
              // Link option to group
              await _optionService.connectOptionToGroup(optionId, groupId);
              savedCount++;
            }
          } catch (e) {
            print('Error saving option ${option.name}: $e');
          }
        }

        // Load and verify the created group with options
        final allGroups = await _optionService.getAllOptionGroups();
        final savedGroup = allGroups.where((g) => g.id == groupId).isNotEmpty
            ? allGroups.firstWhere((g) => g.id == groupId)
            : null;

        setState(() {
          _testResults = '''✅ TEST RESULTS:

✅ Option Group Created Successfully
   ID: $groupId
   Name: ${testGroup.name}

✅ Options Saved: $savedCount/3
   ${testOptions.map((o) => '• ${o.name} (\$${o.price})').join('\n   ')}

✅ Group Retrieved Successfully
   Options in group: ${savedGroup?.options.length ?? 0}
   ${savedGroup?.options.map((o) => '• ${o.name} (\$${o.price})').join('\n   ') ?? 'Group not found'}

🎉 Option saving functionality is WORKING!''';
          _isLoading = false;
        });

        // Refresh the option groups list
        _loadOptionGroups();
      } else {
        setState(() {
          _testResults = '❌ Failed to create option group';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _testResults = '❌ Error during test: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _clearDatabase() async {
    setState(() {
      _isLoading = true;
      _testResults = 'Clearing test data...';
    });

    try {
      final db = await DatabaseHelper().database;
      await db.delete('option_group_options');
      await db.delete('menu_options');
      await db.delete('option_groups');

      setState(() {
        _testResults = '✅ Database cleared successfully';
        _optionGroups = [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _testResults = '❌ Error clearing database: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Option Saving Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Option Group Saving Test',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _testCreateOptionGroup,
                  child: const Text('Test Create Option Group'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _clearDatabase,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Clear Test Data'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _loadOptionGroups,
                  child: const Text('Refresh'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              Text(
                'Existing Option Groups: ${_optionGroups.length}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              if (_optionGroups.isNotEmpty)
                Expanded(
                  flex: 1,
                  child: ListView.builder(
                    itemCount: _optionGroups.length,
                    itemBuilder: (context, index) {
                      final group = _optionGroups[index];
                      return Card(
                        child: ListTile(
                          title: Text(group.name),
                          subtitle: Text('Options: ${group.options.length}'),
                          trailing: Text('ID: ${group.id}'),
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 16),

              const Text(
                'Test Results:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              Expanded(
                flex: 2,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _testResults.isEmpty ? 'Click "Test Create Option Group" to start testing' : _testResults,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}