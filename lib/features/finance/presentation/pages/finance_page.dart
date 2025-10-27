import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../services/supabase_service.dart';

class FinancePage extends ConsumerStatefulWidget {
  const FinancePage({super.key});

  @override
  ConsumerState<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends ConsumerState<FinancePage> {
  bool _isLoading = false;
  double _todayIncome = 0.0;
  double _todayExpenses = 0.0;
  List<FinanceEntry> _todayEntries = [];
  final _financeService = SupabaseFinanceService();

  @override
  void initState() {
    super.initState();
    _loadTodayFinance();
  }

  Future<void> _loadTodayFinance() async {
    setState(() => _isLoading = true);

    try {
      // Load today's finance data from database
      final todayEntries = await _financeService.getTodayFinanceEntries();

      // Convert database records to FinanceEntry objects
      _todayEntries = todayEntries.map((entry) => FinanceEntry(
        id: entry['id'] as String,
        type: entry['type'] == 'income' ? FinanceEntryType.income : FinanceEntryType.expense,
        amount: (entry['amount'] as num).toDouble(),
        description: entry['description'] as String,
        category: entry['category'] as String,
        createdAt: DateTime.parse(entry['created_at'] as String),
      )).toList();

      // Calculate totals
      _todayIncome = _todayEntries
          .where((entry) => entry.type == FinanceEntryType.income)
          .fold(0.0, (sum, entry) => sum + entry.amount);

      _todayExpenses = _todayEntries
          .where((entry) => entry.type == FinanceEntryType.expense)
          .fold(0.0, (sum, entry) => sum + entry.amount);

    } catch (e) {
      print('Error loading finance data: $e');
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading finance data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTodayFinance,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Today's Summary
                    _buildTodaySummary(),
                    const SizedBox(height: 20),

                    // Finance Entries
                    _buildFinanceEntries(),
                  ],
                ),
              ),
            ),

      // 🆕 Floating Action Button with 2 options (like menu page)
      floatingActionButton: _buildFinanceActionButton(),
    );
  }

  Widget _buildTodaySummary() {
    final profit = _todayIncome - _todayExpenses;
    final isProfit = profit >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'finance_page.today_summary'.tr(),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            // Income Card
            Expanded(
              child: _buildSummaryCard(
                title: 'finance_page.income'.tr(),
                amount: _todayIncome,
                color: Colors.green,
                icon: Icons.trending_up,
              ),
            ),
            const SizedBox(width: 12),

            // Expense Card
            Expanded(
              child: _buildSummaryCard(
                title: 'finance_page.expenses'.tr(),
                amount: _todayExpenses,
                color: Colors.red,
                icon: Icons.trending_down,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Profit/Loss Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isProfit ? Colors.green[50] : Colors.red[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isProfit ? Colors.green[200]! : Colors.red[200]!,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isProfit ? Icons.trending_up : Icons.trending_down,
                color: isProfit ? Colors.green[700] : Colors.red[700],
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isProfit ? 'finance_page.profit'.tr() : 'finance_page.loss'.tr(),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${profit.abs().toStringAsFixed(0)}đ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isProfit ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required MaterialColor color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color[700], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${amount.toStringAsFixed(0)}đ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceEntries() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'finance_page.today_entries'.tr(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        if (_todayEntries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Icon(Icons.receipt_long, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'finance_page.no_entries'.tr(),
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'finance_page.add_first_entry'.tr(),
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          )
        else
          ..._todayEntries.map((entry) => _buildFinanceEntryCard(entry)),
      ],
    );
  }

  Widget _buildFinanceEntryCard(FinanceEntry entry) {
    final isIncome = entry.type == FinanceEntryType.income;
    final color = isIncome ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(
            isIncome ? Icons.add : Icons.remove,
            color: color.shade700,
          ),
        ),
        title: Text(
          entry.description,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _formatTime(entry.createdAt),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Text(
          '${isIncome ? '+' : '-'}${entry.amount.toStringAsFixed(0)}đ',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color.shade700,
          ),
        ),
      ),
    );
  }

  // 🆕 Floating Action Button with 2 options (similar to menu page style)
  Widget _buildFinanceActionButton() {
    return FloatingActionButton(
      onPressed: _showFinanceActions,
      backgroundColor: Colors.blue[600],
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  void _showFinanceActions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'finance_page.add_entry'.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Add Income Option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.trending_up, color: Colors.green[700]),
              ),
              title: Text('finance_page.add_income'.tr()),
              subtitle: Text('finance_page.add_income_desc'.tr()),
              onTap: () {
                Navigator.pop(context);
                _showAddIncomeDialog();
              },
            ),

            const SizedBox(height: 8),

            // Add Expense Option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.trending_down, color: Colors.red[700]),
              ),
              title: Text('finance_page.add_expense'.tr()),
              subtitle: Text('finance_page.add_expense_desc'.tr()),
              onTap: () {
                Navigator.pop(context);
                _showAddExpenseDialog();
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showAddIncomeDialog() {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedCategory = 'finance_page.category_sales'.tr();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('finance_page.add_income'.tr()),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amount field
              TextField(
                controller: amountController,
                decoration: InputDecoration(
                  labelText: 'finance_page.amount'.tr(),
                  hintText: '0',
                  suffixText: 'đ',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              const SizedBox(height: 16),

              // Description field
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'finance_page.description'.tr(),
                  hintText: 'finance_page.income_description_hint'.tr(),
                  border: const OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),

              // Category dropdown
              Text(
                'finance_page.category'.tr(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: [
                  'finance_page.category_sales'.tr(),
                  'finance_page.category_catering'.tr(),
                  'finance_page.category_delivery'.tr(),
                  'finance_page.category_tips'.tr(),
                  'finance_page.category_other'.tr(),
                ].map((category) => DropdownMenuItem(
                  value: category,
                  child: Text(category),
                )).toList(),
                onChanged: (value) {
                  selectedCategory = value!;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('finance_page.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              final description = descriptionController.text.trim();

              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('finance_page.invalid_amount'.tr()),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (description.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('finance_page.description_required'.tr()),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // Add income entry
              await _addFinanceEntry(
                type: FinanceEntryType.income,
                amount: amount,
                description: description,
                category: selectedCategory,
              );

              if (mounted) {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('finance_page.add'.tr()),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseDialog() {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedCategory = 'finance_page.category_ingredients'.tr();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('finance_page.add_expense'.tr()),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amount field
              TextField(
                controller: amountController,
                decoration: InputDecoration(
                  labelText: 'finance_page.amount'.tr(),
                  hintText: '0',
                  suffixText: 'đ',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              const SizedBox(height: 16),

              // Description field
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'finance_page.description'.tr(),
                  hintText: 'finance_page.description_hint'.tr(),
                  border: const OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),

              // Category dropdown
              Text(
                'finance_page.category'.tr(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: [
                  'finance_page.category_ingredients'.tr(),
                  'finance_page.category_staff'.tr(),
                  'finance_page.category_utilities'.tr(),
                  'finance_page.category_marketing'.tr(),
                  'finance_page.category_other'.tr(),
                ].map((category) => DropdownMenuItem(
                  value: category,
                  child: Text(category),
                )).toList(),
                onChanged: (value) {
                  selectedCategory = value!;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('finance_page.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              final description = descriptionController.text.trim();

              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('finance_page.invalid_amount'.tr()),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (description.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('finance_page.description_required'.tr()),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // Add expense entry
              await _addFinanceEntry(
                type: FinanceEntryType.expense,
                amount: amount,
                description: description,
                category: selectedCategory,
              );

              if (mounted) {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('finance_page.add'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _addFinanceEntry({
    required FinanceEntryType type,
    required double amount,
    required String description,
    required String category,
  }) async {
    try {
      // Save to database
      final entryId = await _financeService.createFinanceEntry(
        type: type == FinanceEntryType.income ? 'income' : 'expense',
        amount: amount,
        description: description,
        category: category,
      );

      // Create local entry with the database ID
      final newEntry = FinanceEntry(
        id: entryId,
        type: type,
        amount: amount,
        description: description,
        category: category,
        createdAt: DateTime.now(),
      );

      setState(() {
        _todayEntries.add(newEntry);

        // Update totals
        if (type == FinanceEntryType.income) {
          _todayIncome += amount;
        } else {
          _todayExpenses += amount;
        }

        // Sort entries by time (newest first)
        _todayEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              type == FinanceEntryType.income
                  ? 'finance_page.income_added'.tr()
                  : 'finance_page.expense_added'.tr(),
            ),
            backgroundColor: type == FinanceEntryType.income ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error saving finance entry: $e');
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving entry: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }
}

// Simple data models for finance entries
enum FinanceEntryType { income, expense }

class FinanceEntry {
  final String id;
  final FinanceEntryType type;
  final double amount;
  final String description;
  final String category;
  final DateTime createdAt;

  FinanceEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.category,
    required this.createdAt,
  });
}