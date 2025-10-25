import 'package:flutter/material.dart';
import 'services/supabase_service.dart';

/// Test page to verify Supabase integration works
class TestSupabasePage extends StatefulWidget {
  const TestSupabasePage({super.key});

  @override
  State<TestSupabasePage> createState() => _TestSupabasePageState();
}

class _TestSupabasePageState extends State<TestSupabasePage> {
  final SupabaseMenuService _menuService = SupabaseMenuService();
  final SupabaseCustomerService _customerService = SupabaseCustomerService();
  final SupabaseOrderService _orderService = SupabaseOrderService();

  String _testResults = 'Ready to test Supabase connection...';
  bool _isLoading = false;

  Future<void> _runTests() async {
    setState(() {
      _isLoading = true;
      _testResults = 'Running Supabase tests...\n\n';
    });

    try {
      // Test 1: Fetch menu categories
      _updateResults('📂 Testing menu categories...');
      final categories = await _menuService.getCategories();
      _updateResults('✅ Categories loaded: ${categories.length} found');
      for (var category in categories) {
        _updateResults('   - ${category.name}');
      }

      // Test 2: Fetch menu items
      _updateResults('\n🍽️ Testing menu items...');
      final menuItems = await _menuService.getMenuItems();
      _updateResults('✅ Menu items loaded: ${menuItems.length} found');

      // Test 3: Fetch customers
      _updateResults('\n👥 Testing customers...');
      final customers = await _customerService.getCustomers();
      _updateResults('✅ Customers loaded: ${customers.length} found');

      // Test 4: Fetch orders
      _updateResults('\n📋 Testing orders...');
      final orders = await _orderService.getOrders();
      _updateResults('✅ Orders loaded: ${orders.length} found');

      _updateResults('\n🎉 All Supabase tests passed successfully!');
      _updateResults('\nYour app is ready to use cloud database! ☁️');

    } catch (e) {
      _updateResults('\n❌ Test failed: $e');
      _updateResults('\nPlease check your Supabase configuration.');
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _updateResults(String message) {
    setState(() {
      _testResults += '$message\n';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supabase Test'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Supabase Integration Test',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This will test if your app can connect to Supabase and fetch data from all tables.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _runTests,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: _isLoading
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Testing...'),
                      ],
                    )
                  : const Text(
                      'Run Supabase Tests',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _testResults,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
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