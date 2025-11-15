import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/transaction_service.dart';
import '../../../../models/payment_method.dart';
import '../../../../models/transaction.dart';
import '../../../../core/utils/error_messages.dart';
import '../widgets/revenue_distribution_chart.dart';

// Enums for filtering
enum DateRangeType { today, yesterday, thisWeek, lastWeek, thisMonth, lastMonth, custom }

class FinancePage extends ConsumerStatefulWidget {
  const FinancePage({super.key});

  @override
  ConsumerState<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends ConsumerState<FinancePage>
    with SingleTickerProviderStateMixin {
  // Tab controller
  late TabController _tabController;

  // Data loading state
  bool _isLoading = false;

  // Financial data
  double _currentIncome = 0.0;
  double _currentExpenses = 0.0;
  List<FinanceEntry> _allEntries = [];
  List<FinanceEntry> _filteredEntries = [];

  // Filter state
  DateRangeType _selectedDateRange = DateRangeType.today;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  String _searchQuery = '';
  String? _selectedType; // 'income', 'expense', or null for all
  List<String> _selectedSources = [];
  RangeValues _amountRange = const RangeValues(0, 1000000);
  bool _showAdvancedFilters = false;

  // Track recently added entries to show them regardless of filters
  Set<String> _recentlyAddedEntries = {};

  final _financeService = SupabaseFinanceService();
  final _transactionService = TransactionService();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFinanceData(clearRecentlyAdded: false); // Don't clear on initial load
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFinanceData({bool clearRecentlyAdded = false}) async {
    setState(() => _isLoading = true);

    // Only clear recently added entries when explicitly requested
    // Default to false to preserve user experience - newly added entries should stay visible
    if (clearRecentlyAdded) {
      _recentlyAddedEntries.clear();
    }

    try {
      // Load ALL finance data from database (without date filtering)
      // We'll handle date filtering in _applyFilters for more control
      final entries = await _financeService.getFinanceEntries();

      // Convert database records to FinanceEntry objects
      final dbEntries = entries.map((entry) {
        final dbTimestamp = DateTime.parse(entry['created_at'] as String);
        final localTimestamp = dbTimestamp.toLocal(); // Convert to local time

        return FinanceEntry(
          id: entry['id'] as String,
          type: entry['type'] == 'income' ? FinanceEntryType.income : FinanceEntryType.expense,
          amount: (entry['amount'] as num).toDouble(),
          description: entry['description'] as String,
          category: entry['category'] as String,
          createdAt: localTimestamp, // Use local time for consistency
        );
      }).toList();

      // Merge database entries with existing local entries intelligently
      final entryMap = <String, FinanceEntry>{};

      // First, preserve all existing local entries (especially recently added ones)
      for (final entry in _allEntries) {
        entryMap[entry.id] = entry;
      }

      // Then add database entries, but don't overwrite existing local entries
      // This preserves recently added entries that might have slight timestamp differences
      for (final dbEntry in dbEntries) {
        if (!entryMap.containsKey(dbEntry.id)) {
          entryMap[dbEntry.id] = dbEntry;
        }
      }

      // Convert back to list and sort by creation time (newest first)
      _allEntries = entryMap.values.toList();
      _allEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Apply current filters
      _applyFilters();

    } catch (e) {
      // Show user-friendly error message
      if (mounted) {
        ErrorMessages.showErrorSnackbar(
          context,
          e,
          customMessage: ErrorMessages.loadingFinanceError,
        );
      }
    }

    setState(() => _isLoading = false);
  }

  Map<String, DateTime> _getDateRange(DateRangeType type) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (type) {
      case DateRangeType.today:
        return {
          'start': today,
          'end': DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
        };
      case DateRangeType.yesterday:
        final yesterday = today.subtract(const Duration(days: 1));
        return {
          'start': yesterday,
          'end': DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59),
        };
      case DateRangeType.thisWeek:
        final startOfWeek = today.subtract(Duration(days: now.weekday - 1));
        return {
          'start': startOfWeek,
          'end': DateTime(now.year, now.month, now.day, 23, 59, 59),
        };
      case DateRangeType.lastWeek:
        final startOfLastWeek = today.subtract(Duration(days: now.weekday + 6));
        final endOfLastWeek = startOfLastWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        return {
          'start': startOfLastWeek,
          'end': endOfLastWeek,
        };
      case DateRangeType.thisMonth:
        return {
          'start': DateTime(now.year, now.month, 1),
          'end': DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        };
      case DateRangeType.lastMonth:
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        return {
          'start': lastMonth,
          'end': DateTime(now.year, now.month, 0, 23, 59, 59),
        };
      case DateRangeType.custom:
        return {
          'start': _customStartDate ?? today,
          'end': _customEndDate ?? DateTime(now.year, now.month, now.day, 23, 59, 59),
        };
    }
  }

  void _applyFilters() {
    // Get current date range for filtering
    final dateRange = _getDateRange(_selectedDateRange);
    final startDate = dateRange['start']!;
    final endDate = dateRange['end']!;

    _filteredEntries = _allEntries.where((entry) {
      // Always include recently added entries regardless of filters
      if (_recentlyAddedEntries.contains(entry.id)) {
        return true;
      }

      // Date range filter - this is crucial for proper filtering
      // Use more robust date comparison that handles timezone issues
      final entryDate = DateTime(entry.createdAt.year, entry.createdAt.month, entry.createdAt.day);
      final filterStartDate = DateTime(startDate.year, startDate.month, startDate.day);
      final filterEndDate = DateTime(endDate.year, endDate.month, endDate.day);

      // Special handling for auto-created income entries from orders
      // These should be visible even if there are minor timezone discrepancies
      final isAutoCreatedIncome = entry.type == FinanceEntryType.income &&
                                 entry.description.contains('Order ') &&
                                 entry.description.contains('ORD-');

      if (entryDate.isBefore(filterStartDate) || entryDate.isAfter(filterEndDate)) {
        // For auto-created income entries, be more lenient with today's date
        if (isAutoCreatedIncome && _selectedDateRange == DateRangeType.today) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final entryIsToday = entryDate.isAtSameMomentAs(today) ||
                              entryDate.isAfter(today.subtract(const Duration(hours: 6))); // Allow 6 hours buffer

          if (entryIsToday) {
            return true;
          }
        }

        return false;
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        if (!entry.description.toLowerCase().contains(_searchQuery.toLowerCase()) &&
            !entry.category.toLowerCase().contains(_searchQuery.toLowerCase()) &&
            !entry.amount.toString().contains(_searchQuery)) {
          return false;
        }
      }

      // Type filter
      if (_selectedType != null) {
        final entryType = entry.type == FinanceEntryType.income ? 'income' : 'expense';
        if (entryType != _selectedType) return false;
      }

      // Amount range filter
      if (entry.amount < _amountRange.start || entry.amount > _amountRange.end) {
        return false;
      }

      // Source filter (check category contains source name)
      if (_selectedSources.isNotEmpty) {
        bool matchesSource = false;
        for (final source in _selectedSources) {
          if (entry.category.toLowerCase().contains(source.toLowerCase())) {
            matchesSource = true;
            break;
          }
        }
        if (!matchesSource) return false;
      }

      return true;
    }).toList();

    // Sort filtered entries with recently added entries at the top
    _filteredEntries.sort((a, b) {
      // Recently added entries always come first
      final aIsRecent = _recentlyAddedEntries.contains(a.id);
      final bIsRecent = _recentlyAddedEntries.contains(b.id);

      if (aIsRecent && !bIsRecent) return -1; // a comes first
      if (!aIsRecent && bIsRecent) return 1;  // b comes first

      // If both or neither are recent, sort by creation time (newest first)
      return b.createdAt.compareTo(a.createdAt);
    });


    // Calculate totals for filtered entries
    _currentIncome = _filteredEntries
        .where((entry) => entry.type == FinanceEntryType.income)
        .fold(0.0, (sum, entry) => sum + entry.amount);

    _currentExpenses = _filteredEntries
        .where((entry) => entry.type == FinanceEntryType.expense)
        .fold(0.0, (sum, entry) => sum + entry.amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Tab bar only (no duplicate header since MainLayout provides AppBar)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  text: 'finance_page.summary_tab'.tr(),
                ),
                Tab(
                  text: 'finance_page.transactions_tab'.tr(),
                ),
              ],
              indicatorColor: Theme.of(context).primaryColor,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),

          // Tab views
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Summary Tab
                      _buildSummaryTab(),
                      // Transactions Tab
                      _buildTransactionsTab(),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: _buildFinanceActionButton(),
    );
  }

  // ========================= TAB BUILDERS =========================

  Widget _buildSummaryTab() {
    return RefreshIndicator(
      onRefresh: () => _loadFinanceData(clearRecentlyAdded: false),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Range Picker
            _buildDateRangePicker(),
            const SizedBox(height: 20),

            // KPI Cards
            _buildKPICards(),
            const SizedBox(height: 20),

            // Quick Insights
            _buildQuickInsights(),
            const SizedBox(height: 20),

            // Revenue Distribution Chart
            RevenueDistributionChart(
              startDate: _getStartDate(),
              endDate: _getEndDate(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsTab() {
    return Column(
      key: ValueKey('transactions_tab_${_filteredEntries.length}'),
      children: [
        // Filter Bar
        _buildFilterBar(),

        // Filtered Results Summary
        if (_filteredEntries.isNotEmpty) _buildFilteredSummary(),

        // Transaction List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadFinanceData(clearRecentlyAdded: false),
            child: _buildTransactionList(),
          ),
        ),
      ],
    );
  }

  // ========================= SUMMARY TAB COMPONENTS =========================

  Widget _buildDateRangePicker() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<DateRangeType>(
          value: _selectedDateRange,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.blue[700]),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.blue[800],
          ),
          items: [
            DropdownMenuItem(value: DateRangeType.today, child: Text('finance_page.today'.tr())),
            DropdownMenuItem(value: DateRangeType.yesterday, child: Text('finance_page.yesterday'.tr())),
            DropdownMenuItem(value: DateRangeType.thisWeek, child: Text('finance_page.this_week'.tr())),
            DropdownMenuItem(value: DateRangeType.lastWeek, child: Text('finance_page.last_week'.tr())),
            DropdownMenuItem(value: DateRangeType.thisMonth, child: Text('finance_page.this_month'.tr())),
            DropdownMenuItem(value: DateRangeType.lastMonth, child: Text('finance_page.last_month'.tr())),
            DropdownMenuItem(
              value: DateRangeType.custom,
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Text('finance_page.custom_range'.tr()),
                ],
              ),
            ),
          ],
          onChanged: (DateRangeType? value) {
            if (value != null) {
              if (value == DateRangeType.custom) {
                _showCustomDateRangePicker();
              } else {
                setState(() {
                  _selectedDateRange = value;
                });
                _applyFilters(); // Just re-apply filters instead of reloading data
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildKPICards() {
    final profit = _currentIncome - _currentExpenses;
    final isProfit = profit >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'finance_page.financial_overview'.tr(),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            // Income Card
            Expanded(
              child: _buildSummaryCard(
                title: 'finance_page.income'.tr(),
                amount: _currentIncome,
                color: Colors.green,
                icon: Icons.trending_up,
              ),
            ),
            const SizedBox(width: 12),

            // Expense Card
            Expanded(
              child: _buildSummaryCard(
                title: 'finance_page.expenses'.tr(),
                amount: _currentExpenses,
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

  Widget _buildQuickInsights() {
    final totalTransactions = _filteredEntries.length;
    final avgPerDay = _currentIncome / (_selectedDateRange == DateRangeType.thisMonth ? 30 : 1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: Colors.purple[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'finance_page.quick_insights'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildInsightItem(
                  'finance_page.transactions'.tr(),
                  totalTransactions.toString(),
                  Icons.receipt_long,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInsightItem(
                  'finance_page.avg_daily'.tr(),
                  '${avgPerDay.toStringAsFixed(0)}đ',
                  Icons.trending_up,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.purple[600]),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.purple[600]),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.purple[800],
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
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

  // ========================= TRANSACTIONS TAB COMPONENTS =========================

  Widget _buildFilterBar() {
    final hasActiveFilters = _searchQuery.isNotEmpty ||
                           _selectedType != null ||
                           _selectedSources.isNotEmpty ||
                           _amountRange.start > 0 ||
                           _amountRange.end < 1000000;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Date picker (compact for transactions tab)
              SizedBox(
                width: 120,
                child: _buildCompactDatePicker(),
              ),
              const SizedBox(width: 8),

              // Search bar with expandable filters
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'finance_page.search_transactions'.tr(),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: hasActiveFilters
                        ? Badge(
                            label: Text('${_getActiveFilterCount()}'),
                            child: IconButton(
                              icon: Icon(Icons.tune, color: Colors.blue[600], size: 20),
                              onPressed: _toggleAdvancedFilters,
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.tune, size: 20),
                            onPressed: _toggleAdvancedFilters,
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14),
                  onChanged: (query) {
                    setState(() {
                      _searchQuery = query;
                    });
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),

          // Expandable advanced filters
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _showAdvancedFilters ? null : 0,
            child: _showAdvancedFilters ? _buildAdvancedFilters() : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDatePicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<DateRangeType>(
          value: _selectedDateRange,
          isDense: true,
          style: TextStyle(fontSize: 11, color: Colors.blue[800]),
          icon: Icon(Icons.arrow_drop_down, size: 16, color: Colors.blue[600]),
          items: [
            DropdownMenuItem(
              value: DateRangeType.today,
              child: Text('finance_page.today'.tr(), style: const TextStyle(fontSize: 11))
            ),
            DropdownMenuItem(
              value: DateRangeType.thisWeek,
              child: Text('finance_page.this_week'.tr(), style: const TextStyle(fontSize: 11))
            ),
            DropdownMenuItem(
              value: DateRangeType.thisMonth,
              child: Text('finance_page.this_month'.tr(), style: const TextStyle(fontSize: 11))
            ),
            DropdownMenuItem(
              value: DateRangeType.custom,
              child: Text('finance_page.custom'.tr(), style: const TextStyle(fontSize: 11))
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              if (value == DateRangeType.custom) {
                _showCustomDateRangePicker();
              } else {
                setState(() {
                  _selectedDateRange = value;
                });
                _applyFilters(); // Just re-apply filters instead of reloading data
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildAdvancedFilters() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter chips row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: Text('finance_page.income'.tr()),
                  selected: _selectedType == 'income',
                  onSelected: (selected) {
                    setState(() {
                      _selectedType = selected ? 'income' : null;
                    });
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('finance_page.expenses'.tr()),
                  selected: _selectedType == 'expense',
                  onSelected: (selected) {
                    setState(() {
                      _selectedType = selected ? 'expense' : null;
                    });
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('finance_page.direct_sales'.tr()),
                  selected: _selectedSources.contains('Direct'),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedSources.add('Direct');
                      } else {
                        _selectedSources.remove('Direct');
                      }
                    });
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('finance_page.delivery'.tr()),
                  selected: _selectedSources.contains('Grab') || _selectedSources.contains('Shopee'),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedSources.addAll(['Grab', 'Shopee']);
                      } else {
                        _selectedSources.removeWhere((source) => ['Grab', 'Shopee'].contains(source));
                      }
                    });
                    _applyFilters();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Amount range slider
          Text(
            'finance_page.amount_range'.tr(),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          RangeSlider(
            values: _amountRange,
            min: 0,
            max: 1000000,
            divisions: 20,
            labels: RangeLabels(
              '${_amountRange.start.round()}đ',
              '${_amountRange.end.round()}đ',
            ),
            onChanged: (range) {
              setState(() {
                _amountRange = range;
              });
            },
            onChangeEnd: (range) {
              _applyFilters();
            },
          ),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _clearAllFilters,
                child: Text('finance_page.clear_all'.tr()),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => setState(() => _showAdvancedFilters = false),
                child: Text('finance_page.done'.tr()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredSummary() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(bottom: BorderSide(color: Colors.blue[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'finance_page.filtered_results'.tr(namedArgs: {'count': _filteredEntries.length.toString()}),
            style: TextStyle(fontSize: 14, color: Colors.blue[800]),
          ),
          Text(
            'finance_page.net_amount'.tr(namedArgs: {'amount': (_currentIncome - _currentExpenses).toStringAsFixed(0)}),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {

    if (_filteredEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'finance_page.no_transactions'.tr(),
              style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              'finance_page.try_different_filters'.tr(),
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      key: ValueKey('transaction_list_${_filteredEntries.length}'), // Force rebuild when count changes
      padding: const EdgeInsets.all(16),
      itemCount: _filteredEntries.length,
      itemBuilder: (context, index) {
        final entry = _filteredEntries[index];
        return _buildFinanceEntryCard(entry);
      },
    );
  }

  // ========================= HELPER METHODS =========================

  void _showCustomDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _customStartDate ?? DateTime.now().subtract(const Duration(days: 7)),
        end: _customEndDate ?? DateTime.now(),
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = DateRangeType.custom;
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
      _applyFilters(); // Just re-apply filters instead of reloading data
    }
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_selectedType != null) count++;
    if (_selectedSources.isNotEmpty) count++;
    if (_amountRange.start > 0 || _amountRange.end < 1000000) count++;
    return count;
  }

  void _toggleAdvancedFilters() {
    setState(() {
      _showAdvancedFilters = !_showAdvancedFilters;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedType = null;
      _selectedSources.clear();
      _amountRange = const RangeValues(0, 1000000);
      _searchQuery = '';
      _searchController.clear();
    });
    _applyFilters();
  }

  Widget _buildFinanceEntryCard(FinanceEntry entry) {
    final isIncome = entry.type == FinanceEntryType.income;
    final color = isIncome ? Colors.green : Colors.red;
    final isRecentlyAdded = _recentlyAddedEntries.contains(entry.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isRecentlyAdded ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isRecentlyAdded
            ? BorderSide(color: Colors.blue.shade300, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(
            isIncome ? Icons.add : Icons.remove,
            color: color.shade700,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                entry.description,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (isRecentlyAdded)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'NEW',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          _formatTime(entry.createdAt),
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
    PaymentMethodType? selectedPaymentMethod;

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
              const SizedBox(height: 16),

              // Payment method dropdown
              Text(
                'Payment Method',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<PaymentMethodType>(
                initialValue: selectedPaymentMethod,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Select payment method',
                ),
                items: PaymentMethodType.values.map((method) => DropdownMenuItem(
                  value: method,
                  child: Row(
                    children: [
                      Text(method.icon),
                      const SizedBox(width: 8),
                      Text(method.displayName),
                    ],
                  ),
                )).toList(),
                onChanged: (value) {
                  selectedPaymentMethod = value;
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a payment method';
                  }
                  return null;
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
              final navigator = Navigator.of(context);

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

              if (selectedPaymentMethod == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please select a payment method'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // Add income entry using new TransactionService
              await _addFinanceEntryWithPayment(
                type: FinanceEntryType.income,
                amount: amount,
                description: description,
                category: selectedCategory,
                paymentMethod: selectedPaymentMethod!,
              );

              if (mounted) {
                navigator.pop();
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
    String selectedCategory = 'finance_page.category_staff'.tr();
    PaymentMethodType? selectedPaymentMethod;

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
              const SizedBox(height: 16),

              // Payment method dropdown
              Text(
                'Payment Method',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<PaymentMethodType>(
                initialValue: selectedPaymentMethod,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Select payment method',
                ),
                items: PaymentMethodType.values.map((method) => DropdownMenuItem(
                  value: method,
                  child: Row(
                    children: [
                      Text(method.icon),
                      const SizedBox(width: 8),
                      Text(method.displayName),
                    ],
                  ),
                )).toList(),
                onChanged: (value) {
                  selectedPaymentMethod = value;
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a payment method';
                  }
                  return null;
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
              final navigator = Navigator.of(context);

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

              if (selectedPaymentMethod == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please select a payment method'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // Add expense entry using new TransactionService
              await _addFinanceEntryWithPayment(
                type: FinanceEntryType.expense,
                amount: amount,
                description: description,
                category: selectedCategory,
                paymentMethod: selectedPaymentMethod!,
              );

              if (mounted) {
                navigator.pop();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('finance_page.add'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _addFinanceEntryWithPayment({
    required FinanceEntryType type,
    required double amount,
    required String description,
    required String category,
    required PaymentMethodType paymentMethod,
  }) async {
    try {
      // Use TransactionService to create the transaction with payment method
      final transaction = type == FinanceEntryType.income
          ? await _transactionService.createTransaction(
              transactionType: TransactionType.revenue,
              referenceType: ReferenceType.manual,
              paymentMethod: paymentMethod,
              amount: amount,
              category: _mapCategoryToKey(category),
              description: description,
              accountFrom: 'customer_${paymentMethod.name}',
              accountTo: 'revenue_${_mapCategoryToKey(category)}',
              transactionTime: DateTime.now(),
            )
          : await _transactionService.createExpense(
              paymentMethod: paymentMethod,
              amount: amount,
              category: _mapCategoryToKey(category),
              description: description,
              transactionTime: DateTime.now(),
            );

      if (transaction == null) {
        throw Exception('Failed to create transaction');
      }

      // Create local entry for the UI
      final currentTime = DateTime.now();
      final newEntry = FinanceEntry(
        id: transaction.id,
        type: type,
        amount: amount,
        description: description,
        category: category,
        createdAt: currentTime,
      );

      setState(() {
        // Add new entry to the beginning of the list so it appears first
        _allEntries.insert(0, newEntry);

        // Sort all entries by creation time (newest first) to ensure proper ordering
        _allEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // Mark this entry as recently added so it appears regardless of filters
        _recentlyAddedEntries.add(newEntry.id);

        // Re-apply filters with the new entry included
        _applyFilters();
      });

      // Switch to transactions tab to show the new entry
      if (_tabController.index == 0) {
        _tabController.animateTo(1);
      }

      // Clear the recently added flag after 5 minutes so normal filtering resumes
      Future.delayed(const Duration(minutes: 5), () {
        if (mounted) {
          setState(() {
            _recentlyAddedEntries.remove(transaction.id);
            _applyFilters();
          });
        }
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
      // Show user-friendly error message
      if (mounted) {
        ErrorMessages.showErrorSnackbar(
          context,
          e,
          customMessage: ErrorMessages.savingFinanceEntryError,
        );
      }
    }
  }

  /// Get start date based on selected date range
  DateTime? _getStartDate() {
    final now = DateTime.now();
    switch (_selectedDateRange) {
      case DateRangeType.today:
        return DateTime(now.year, now.month, now.day);
      case DateRangeType.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        return DateTime(yesterday.year, yesterday.month, yesterday.day);
      case DateRangeType.thisWeek:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      case DateRangeType.lastWeek:
        final startOfLastWeek = now.subtract(Duration(days: now.weekday + 6));
        return DateTime(startOfLastWeek.year, startOfLastWeek.month, startOfLastWeek.day);
      case DateRangeType.thisMonth:
        return DateTime(now.year, now.month, 1);
      case DateRangeType.lastMonth:
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        return lastMonth;
      case DateRangeType.custom:
        return _customStartDate;
    }
  }

  /// Get end date based on selected date range
  DateTime? _getEndDate() {
    final now = DateTime.now();
    switch (_selectedDateRange) {
      case DateRangeType.today:
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
      case DateRangeType.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        return DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
      case DateRangeType.thisWeek:
        final endOfWeek = now.add(Duration(days: 7 - now.weekday));
        return DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day, 23, 59, 59);
      case DateRangeType.lastWeek:
        final endOfLastWeek = now.subtract(Duration(days: now.weekday));
        return DateTime(endOfLastWeek.year, endOfLastWeek.month, endOfLastWeek.day, 23, 59, 59);
      case DateRangeType.thisMonth:
        final nextMonth = DateTime(now.year, now.month + 1, 1);
        return nextMonth.subtract(const Duration(microseconds: 1));
      case DateRangeType.lastMonth:
        final thisMonth = DateTime(now.year, now.month, 1);
        return thisMonth.subtract(const Duration(microseconds: 1));
      case DateRangeType.custom:
        return _customEndDate;
    }
  }

  /// Map UI category names to database category keys
  String _mapCategoryToKey(String category) {
    // Income categories
    if (category == 'finance_page.category_sales'.tr()) return 'food_sales';
    if (category == 'finance_page.category_catering'.tr()) return 'catering';
    if (category == 'finance_page.category_delivery'.tr()) return 'delivery';
    if (category == 'finance_page.category_tips'.tr()) return 'tips';

    // Expense categories
    if (category == 'finance_page.category_staff'.tr()) return 'wages';
    if (category == 'finance_page.category_utilities'.tr()) return 'utilities';
    if (category == 'finance_page.category_marketing'.tr()) return 'marketing';

    // Default to 'other' for unmatched categories
    return 'other';
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