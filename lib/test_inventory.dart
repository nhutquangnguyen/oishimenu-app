import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'models/inventory_models.dart';
import 'features/inventory/providers/inventory_provider.dart';

void main() {
  runApp(const ProviderScope(child: InventoryTestApp()));
}

class InventoryTestApp extends ConsumerWidget {
  const InventoryTestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Inventory Test - Vietnamese Restaurant POS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const InventoryTestPage(),
    );
  }
}

class InventoryTestPage extends ConsumerStatefulWidget {
  const InventoryTestPage({super.key});

  @override
  ConsumerState<InventoryTestPage> createState() => _InventoryTestPageState();
}

class _InventoryTestPageState extends ConsumerState<InventoryTestPage> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management Test'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Ingredients'),
            Tab(text: 'Stocktake'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildIngredientsTab(),
          _buildStocktakeTab(),
        ],
      ),
    );
  }

  Widget _buildIngredientsTab() {
    final statsAsync = ref.watch(inventoryStatsProvider);
    final filter = ref.watch(currentInventoryFilterProvider);
    final ingredientsAsync = ref.watch(ingredientsProvider(filter));
    final categories = ref.watch(inventoryCategoriesProvider);

    return Column(
      children: [
        // Stats Cards
        statsAsync.when(
          data: (stats) => Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Total Items',
                    value: '${stats['total_ingredients'] ?? 0}',
                    icon: Icons.inventory_2,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    title: 'Total Value',
                    value: CurrencyUtils.formatVND(stats['total_value']?.toDouble() ?? 0),
                    icon: Icons.attach_money,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    title: 'Low Stock',
                    value: '${stats['low_stock_count'] ?? 0}',
                    icon: Icons.warning,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error: $e'),
          ),
        ),

        // Controls
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: ref.watch(inventoryCategoryFilterProvider),
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(inventoryCategoryFilterProvider.notifier).state = value;
                    }
                  },
                  items: categories.entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _showCreateSampleDataDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Sample Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Ingredients List
        Expanded(
          child: ingredientsAsync.when(
            data: (ingredients) {
              if (ingredients.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        'No ingredients found',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add some sample data to get started',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _showCreateSampleDataDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Create Sample Data'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: ingredients.length,
                itemBuilder: (context, index) {
                  final ingredient = ingredients[index];
                  return _IngredientCard(ingredient: ingredient);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildStocktakeTab() {
    final sessionsAsync = ref.watch(stocktakeSessionsProvider);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _showCreateStocktakeDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Stocktake Session'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        Expanded(
          child: sessionsAsync.when(
            data: (sessions) {
              if (sessions.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        'No stocktake sessions',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create a session to start counting inventory',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  return _StocktakeCard(session: session);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  void _showCreateSampleDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Sample Data'),
        content: const Text('This will create sample Vietnamese restaurant ingredients with Vietnamese dong pricing.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await ref.read(inventoryActionsProvider.notifier).createSampleData();
              // Refresh data
              ref.invalidate(inventoryStatsProvider);
              ref.invalidate(ingredientsProvider);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showCreateStocktakeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Stocktake Session'),
        content: const Text('This will create a new stocktake session for all active ingredients.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await ref.read(stocktakeActionsProvider.notifier).createStocktakeSession(
                  name: 'Stocktake ${DateTime.now().toString().substring(0, 16)}',
                  description: 'Test stocktake session',
                  type: 'full',
                );
                // Refresh stocktake sessions
                ref.invalidate(stocktakeSessionsProvider);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _IngredientCard extends StatelessWidget {
  final Ingredient ingredient;

  const _IngredientCard({required this.ingredient});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(ingredient.stockStatus);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ingredient.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      if (ingredient.description != null)
                        Text(
                          ingredient.description!,
                          style: const TextStyle(color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(ingredient.stockStatus),
                    style: TextStyle(color: statusColor, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stock: ${CurrencyUtils.formatUnit(ingredient.currentQuantity, ingredient.unit)}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Min: ${CurrencyUtils.formatUnit(ingredient.minimumThreshold, ingredient.unit)}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${CurrencyUtils.formatVND(ingredient.costPerUnit)}/unit',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Total: ${CurrencyUtils.formatVND(ingredient.totalValue)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'in_stock':
        return Colors.green;
      case 'low_stock':
        return Colors.orange;
      case 'critical':
        return Colors.red;
      case 'out_of_stock':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'in_stock':
        return 'In Stock';
      case 'low_stock':
        return 'Low Stock';
      case 'critical':
        return 'Critical';
      case 'out_of_stock':
        return 'Out of Stock';
      default:
        return 'Unknown';
    }
  }
}

class _StocktakeCard extends StatelessWidget {
  final StocktakeSession session;

  const _StocktakeCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(session.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    session.status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(session.status),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (session.description != null) ...[
              const SizedBox(height: 4),
              Text(
                session.description!,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Progress: ${session.countedItems}/${session.totalItems}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  '${session.progressPercentage.toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: session.progressPercentage / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation(_getStatusColor(session.status)),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.grey;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}