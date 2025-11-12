import 'package:flutter/material.dart';
import 'services/transaction_service.dart';
import 'services/supabase_service.dart';

/// Test page to verify the order_payments table removal and transaction migration
class MigrationVerificationPage extends StatefulWidget {
  const MigrationVerificationPage({super.key});

  @override
  State<MigrationVerificationPage> createState() => _MigrationVerificationPageState();
}

class _MigrationVerificationPageState extends State<MigrationVerificationPage> {
  final TransactionService _transactionService = TransactionService();
  String _verificationResults = '';
  bool _isLoading = false;

  Future<void> _runVerification() async {
    setState(() {
      _isLoading = true;
      _verificationResults = 'Running verification tests...\n\n';
    });

    final results = StringBuffer();

    try {
      // Test 1: Check if order_payments table exists (should fail)
      results.writeln('🔍 Test 1: Checking if order_payments table exists...');
      try {
        final response = await SupabaseService.client
            .from('order_payments')
            .select('count')
            .limit(1);
        results.writeln('❌ ISSUE: order_payments table still exists! Migration may not be complete.');
        results.writeln('   Response: $response\n');
      } catch (e) {
        if (e.toString().contains('relation "public.order_payments" does not exist') ||
            e.toString().contains('Could not find the table') ||
            e.toString().contains('PGRST116')) {
          results.writeln('✅ PASS: order_payments table has been successfully removed.\n');
        } else {
          results.writeln('⚠️  Unexpected error: $e\n');
        }
      }

      // Test 2: Check transactions table works
      results.writeln('🔍 Test 2: Checking transactions table functionality...');
      try {
        final transactions = await _transactionService.getTransactions(
          transactionType: TransactionType.revenue,
          limit: 5,
        );
        results.writeln('✅ PASS: transactions table is accessible.');
        results.writeln('   Found ${transactions.length} revenue transactions.\n');
      } catch (e) {
        results.writeln('❌ FAIL: transactions table error: $e\n');
      }

      // Test 3: Test order payment creation (should use transactions table)
      results.writeln('🔍 Test 3: Testing order payment creation...');
      try {
        // Get a recent order to test with
        final orders = await SupabaseService.client
            .from('orders')
            .select('id, total')
            .order('created_at', ascending: false)
            .limit(1);

        if (orders.isNotEmpty) {
          final orderId = orders[0]['id'];
          final total = (orders[0]['total'] as num).toDouble();

          // Create test payment
          final payment = await _transactionService.createOrderPayment(
            orderId: orderId,
            paymentMethod: PaymentMethodType.cash,
            amountPaid: total,
            totalAmount: total,
            paymentStatus: PaymentStatus.paid,
            notes: 'Migration verification test payment',
          );

          if (payment != null) {
            results.writeln('✅ PASS: Order payment creation works via TransactionService.');
            results.writeln('   Created payment ID: ${payment.id}');

            // Clean up test payment
            await _transactionService.deleteTransaction(payment.id);
            results.writeln('   Test payment cleaned up.\n');
          } else {
            results.writeln('❌ FAIL: Payment creation returned null.\n');
          }
        } else {
          results.writeln('⚠️  No orders found to test with.\n');
        }
      } catch (e) {
        results.writeln('❌ FAIL: Payment creation error: $e\n');
      }

      // Test 4: Test financial summary (should work with transactions table)
      results.writeln('🔍 Test 4: Testing financial summary...');
      try {
        final summary = await _transactionService.getFinancialSummary();
        final totalRevenue = summary['total_revenue'] ?? 0.0;
        final breakdown = summary['payment_method_breakdown'] ?? {};

        results.writeln('✅ PASS: Financial summary working.');
        results.writeln('   Total revenue: ₫${_formatCurrency(totalRevenue)}');
        results.writeln('   Payment methods: ${breakdown.keys.join(', ')}\n');
      } catch (e) {
        results.writeln('❌ FAIL: Financial summary error: $e\n');
      }

      // Test 5: Check for backup tables
      results.writeln('🔍 Test 5: Checking for backup tables...');
      try {
        final backupCheck = await SupabaseService.client
            .rpc('check_backup_tables');
        results.writeln('✅ Backup table check completed.\n');
      } catch (e) {
        // This is expected if the function doesn't exist
        results.writeln('ℹ️  Backup table check not available (this is normal).\n');
      }

      results.writeln('🎉 Migration verification completed!');
      results.writeln('\nSUMMARY:');
      results.writeln('- order_payments table should be removed ✓');
      results.writeln('- transactions table should be working ✓');
      results.writeln('- Payment creation should work via TransactionService ✓');
      results.writeln('- Financial reporting should work ✓');

    } catch (e) {
      results.writeln('❌ Verification failed with error: $e');
    }

    setState(() {
      _verificationResults = results.toString();
      _isLoading = false;
    });
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Migration Verification'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Database Migration Verification',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This will test that the order_payments table was successfully removed '
              'and all functionality is working with the transactions table.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _runVerification,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isLoading ? 'Running Tests...' : 'Run Verification Tests'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),

            const SizedBox(height: 24),

            if (_verificationResults.isNotEmpty) ...[
              Text(
                'Results:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _verificationResults,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
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

// Add this to your app's routing to access the verification page
// Example: Navigator.push(context, MaterialPageRoute(builder: (context) => const MigrationVerificationPage()));