import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/inventory_models.dart';
import '../../providers/inventory_provider.dart';
import '../../../../core/localization/app_localizations.dart';

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> with TickerProviderStateMixin {
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
      body: SafeArea(
        child: Column(
          children: [
            // Simple header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 24,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.inventory,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Minimal tab bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey[500],
                indicatorColor: Theme.of(context).primaryColor,
                indicatorWeight: 2.5,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
                dividerColor: Colors.grey[200],
                tabs: [
                  Tab(text: AppLocalizations.ingredients),
                  Tab(text: AppLocalizations.stocktake),
                ],
              ),
            ),

            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildIngredientsTab(),
                  _buildStocktakeTab(),
                ],
              ),
            ),
          ],
        ),
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
        // Minimal stats
        statsAsync.when(
          data: (stats) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                _SimpleStatItem(
                  label: AppLocalizations.items,
                  value: '${stats['total_ingredients'] ?? 0}',
                ),
                const SizedBox(width: 24),
                _SimpleStatItem(
                  label: AppLocalizations.value,
                  value: CurrencyUtils.formatVND(stats['total_value']?.toDouble() ?? 0),
                ),
                const Spacer(),
                if ((stats['low_stock_count'] ?? 0) > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                             size: 14, color: Colors.orange[700]),
                        const SizedBox(width: 4),
                        Text(
                          AppLocalizations.lowStockCount(stats['low_stock_count'] ?? 0),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: Text(AppLocalizations.errorLoadingStats,
                       style: TextStyle(color: Colors.grey[600])),
          ),
        ),

        // Simple controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              // First row with category filter
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: ref.watch(inventoryCategoryFilterProvider),
                          onChanged: (value) {
                            if (value != null) {
                              ref.read(inventoryCategoryFilterProvider.notifier).state = value;
                            }
                          },
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                          items: categories.entries.map((entry) {
                            return DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'sample':
                          _showCreateSampleDataDialog();
                          break;
                        case 'export':
                          _exportInventory();
                          break;
                        case 'clear':
                          _showClearDataDialog();
                          break;
                      }
                    },
                    icon: Icon(Icons.more_vert, size: 20, color: Colors.grey[600]),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'sample',
                        child: Row(
                          children: [
                            const Icon(Icons.data_array, size: 16),
                            const SizedBox(width: 8),
                            Text(AppLocalizations.sampleData),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'export',
                        child: Row(
                          children: [
                            const Icon(Icons.download, size: 16),
                            const SizedBox(width: 8),
                            Text(AppLocalizations.exportCsv),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'clear',
                        child: Row(
                          children: [
                            const Icon(Icons.clear_all, size: 16),
                            const SizedBox(width: 8),
                            Text(AppLocalizations.clearAll),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Second row with action buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _showLowStockDialog,
                      icon: Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange[700]),
                      label: Text(AppLocalizations.lowStock),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange[700],
                        textStyle: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _showAddIngredientDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(AppLocalizations.addItem),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).primaryColor,
                        textStyle: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
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
                      Icon(Icons.inventory_2_outlined,
                           size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.noIngredientsYet,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add sample data to get started',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _showCreateSampleDataDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Create Sample Data'),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).primaryColor,
                          textStyle: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: ingredients.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final ingredient = ingredients[index];
                  return _IngredientCard(
                    ingredient: ingredient,
                    onQuantityChanged: (newQuantity) => _updateIngredientQuantity(ingredient.id!, newQuantity),
                    onEdit: () => _showEditIngredientDialog(ingredient),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading ingredients',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Error: $e',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      ref.invalidate(ingredientsProvider);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStocktakeTab() {
    final sessionsAsync = ref.watch(stocktakeSessionsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Text(
                'Sessions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _showCreateStocktakeDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Session'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).primaryColor,
                  textStyle: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
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
                      Icon(Icons.assignment_outlined,
                           size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No sessions yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create a session to start counting',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: sessions.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  return _StocktakeCard(session: session);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                'Error loading sessions',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _updateIngredientQuantity(int ingredientId, double newQuantity) async {
    try {
      await ref.read(inventoryActionsProvider.notifier).updateQuantity(
        ingredientId,
        newQuantity,
        reason: 'Manual adjustment from inventory page',
      );
      // Only refresh stats, not the entire ingredient list for better performance
      ref.invalidate(inventoryStatsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating quantity: $e')),
        );
      }
    }
  }

  void _showEditIngredientDialog(Ingredient ingredient) {
    _showIngredientFormDialog(ingredient: ingredient);
  }

  void _showAddIngredientDialog() {
    _showIngredientFormDialog();
  }

  void _showIngredientFormDialog({Ingredient? ingredient}) {
    final isEditing = ingredient != null;
    final nameController = TextEditingController(text: ingredient?.name ?? '');
    final descController = TextEditingController(text: ingredient?.description ?? '');
    final quantityController = TextEditingController(text: ingredient?.currentQuantity.toString() ?? '0');
    final minThresholdController = TextEditingController(text: ingredient?.minimumThreshold.toString() ?? '0');
    final costController = TextEditingController(text: ingredient?.costPerUnit.toString() ?? '0');
    final supplierController = TextEditingController(text: ingredient?.supplier ?? '');
    String selectedCategory = ingredient?.category ?? 'vegetables';
    String selectedUnit = ingredient?.unit ?? 'kg';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxWidth: 450, maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Compact Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isEditing ? Icons.edit : Icons.add,
                        color: Theme.of(context).primaryColor,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isEditing ? 'Edit Ingredient' : 'Add Ingredient',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // Compact Form Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Row 1: Name + Category
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildCompactField(
                                controller: nameController,
                                label: 'Name *',
                                icon: Icons.local_dining,
                                hint: 'Ingredient name',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: _buildCompactDropdown(
                                value: selectedCategory,
                                label: 'Category',
                                icon: Icons.category,
                                items: _getCompactCategoryLabels().entries
                                    .map((entry) => DropdownMenuItem(
                                          value: entry.key,
                                          child: Text(entry.value),
                                        ))
                                    .toList(),
                                onChanged: (value) => setState(() => selectedCategory = value!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Row 2: Quantity + Unit
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildCompactField(
                                controller: quantityController,
                                label: 'Quantity *',
                                icon: Icons.scale,
                                hint: '0.0',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: _buildCompactDropdown(
                                value: selectedUnit,
                                label: 'Unit',
                                icon: Icons.straighten,
                                items: ['kg', 'g', 'lít', 'ml', 'cái', 'hộp', 'túi', 'thùng']
                                    .map((unit) => DropdownMenuItem(value: unit, child: Text(unit)))
                                    .toList(),
                                onChanged: (value) => setState(() => selectedUnit = value!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Row 3: Cost + Min Threshold
                        Row(
                          children: [
                            Expanded(
                              child: _buildCompactField(
                                controller: costController,
                                label: 'Cost (VND)',
                                icon: Icons.money,
                                hint: '0',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildCompactField(
                                controller: minThresholdController,
                                label: 'Min Alert',
                                icon: Icons.warning_amber,
                                hint: '0',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Row 4: Description (full width)
                        _buildCompactField(
                          controller: descController,
                          label: 'Description',
                          icon: Icons.description,
                          hint: 'Brief description (optional)',
                          maxLines: 2,
                        ),
                        const SizedBox(height: 10),

                        // Row 5: Supplier (full width)
                        _buildCompactField(
                          controller: supplierController,
                          label: 'Supplier',
                          icon: Icons.business,
                          hint: 'Supplier name (optional)',
                        ),
                      ],
                    ),
                  ),
                ),

                // Compact Action Buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () => _handleFormSubmit(
                            context: context,
                            isEditing: isEditing,
                            ingredient: ingredient,
                            nameController: nameController,
                            descController: descController,
                            quantityController: quantityController,
                            minThresholdController: minThresholdController,
                            costController: costController,
                            supplierController: supplierController,
                            selectedCategory: selectedCategory,
                            selectedUnit: selectedUnit,
                          ),
                          icon: Icon(isEditing ? Icons.update : Icons.add, size: 18),
                          label: Text(isEditing ? 'Update' : 'Add'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Compact form field helper
  Widget _buildCompactField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Compact label
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Row(
            children: [
              Icon(icon, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
        // Compact input field
        SizedBox(
          height: maxLines > 1 ? null : 40,
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  // Compact dropdown helper
  Widget _buildCompactDropdown({
    required String value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Compact label
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Row(
            children: [
              Icon(icon, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
        // Compact dropdown field with overflow handling
        SizedBox(
          height: 40,
          child: DropdownButtonFormField<String>(
            value: value,
            style: const TextStyle(fontSize: 13, color: Colors.black),
            isExpanded: true, // This prevents overflow
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
            ),
            items: items,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // Get compact category labels for better fit
  Map<String, String> _getCompactCategoryLabels() {
    return {
      'dairy': 'Sữa',
      'protein': 'Thịt',
      'vegetables': 'Rau',
      'fruits': 'Trái cây',
      'grains': 'Bánh',
      'spices': 'Gia vị',
      'beverages': 'Đồ uống',
      'other': 'Khác'
    };
  }


  // Handle form submission
  Future<void> _handleFormSubmit({
    required BuildContext context,
    required bool isEditing,
    required Ingredient? ingredient,
    required TextEditingController nameController,
    required TextEditingController descController,
    required TextEditingController quantityController,
    required TextEditingController minThresholdController,
    required TextEditingController costController,
    required TextEditingController supplierController,
    required String selectedCategory,
    required String selectedUnit,
  }) async {
    if (nameController.text.trim().isEmpty ||
        quantityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Text('Please fill all required fields'),
            ],
          ),
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    final quantity = double.tryParse(quantityController.text) ?? 0;
    final threshold = double.tryParse(minThresholdController.text) ?? 0;
    final cost = double.tryParse(costController.text) ?? 0;

    final newIngredient = Ingredient(
      id: ingredient?.id,
      name: nameController.text.trim(),
      description: descController.text.trim().isEmpty ? null : descController.text.trim(),
      category: selectedCategory,
      unit: selectedUnit,
      currentQuantity: quantity,
      minimumThreshold: threshold,
      costPerUnit: cost,
      supplier: supplierController.text.trim().isEmpty ? null : supplierController.text.trim(),
      createdAt: ingredient?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      if (isEditing) {
        await ref.read(inventoryActionsProvider.notifier).updateIngredient(newIngredient);
      } else {
        await ref.read(inventoryActionsProvider.notifier).createIngredient(newIngredient);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isEditing ? Icons.check_circle : Icons.add_circle,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(isEditing ? 'Ingredient updated successfully' : 'Ingredient added successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }

      // Only refresh stats for better performance
      ref.invalidate(inventoryStatsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text('Error: $e'),
              ],
            ),
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  void _showLowStockDialog() async {
    try {
      final stats = await ref.read(inventoryStatsProvider.future);
      final lowStockCount = stats['low_stock_count'] ?? 0;

      if (lowStockCount == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All items are well stocked!')),
          );
        }
        return;
      }

      // Filter to show only low stock items
      ref.read(inventoryLowStockFilterProvider.notifier).state = true;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Showing $lowStockCount low stock items')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _exportInventory() async {
    try {
      final ingredients = await ref.read(ingredientsProvider(null).future);

      if (ingredients.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data to export')),
          );
        }
        return;
      }

      // Create CSV content
      final StringBuffer csv = StringBuffer();
      csv.writeln('Name,Category,Current Quantity,Unit,Minimum Threshold,Cost per Unit,Supplier,Status');

      for (final ingredient in ingredients) {
        csv.writeln([
          ingredient.name,
          ingredient.category,
          ingredient.currentQuantity,
          ingredient.unit,
          ingredient.minimumThreshold,
          ingredient.costPerUnit,
          ingredient.supplier ?? '',
          ingredient.stockStatus,
        ].join(','));
      }

      // Show export dialog (in a real app, you'd save this to file)
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Export Complete'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Exported ${ingredients.length} ingredients'),
                const SizedBox(height: 12),
                const Text('CSV Data:'),
                const SizedBox(height: 8),
                Container(
                  height: 200,
                  width: double.maxFinite,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      csv.toString(),
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will permanently delete all ingredients and stocktake data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // TODO: Implement clear all data functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Clear data feature coming soon')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
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
                  description: 'Vietnamese restaurant inventory count',
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

class _SimpleStatItem extends StatelessWidget {
  final String label;
  final String value;

  const _SimpleStatItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _IngredientCard extends StatelessWidget {
  final Ingredient ingredient;
  final Function(double) onQuantityChanged;
  final VoidCallback onEdit;

  const _IngredientCard({
    required this.ingredient,
    required this.onQuantityChanged,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(ingredient.stockStatus);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
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
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (ingredient.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        ingredient.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (ingredient.stockStatus != 'in_stock')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStatusText(ingredient.stockStatus),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InfoRow(
                  label: 'Stock',
                  value: CurrencyUtils.formatUnit(ingredient.currentQuantity, ingredient.unit),
                ),
              ),
              Expanded(
                child: _InfoRow(
                  label: 'Cost',
                  value: CurrencyUtils.formatVND(ingredient.costPerUnit),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Quantity adjustment buttons
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        if (ingredient.currentQuantity > 0) {
                          onQuantityChanged(ingredient.currentQuantity - 1);
                        }
                      },
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Icon(Icons.remove, size: 16, color: Colors.grey[600]),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.symmetric(
                          vertical: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Text(
                        ingredient.currentQuantity.toString(),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    InkWell(
                      onTap: () => onQuantityChanged(ingredient.currentQuantity + 1),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Icon(Icons.add, size: 16, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: onEdit,
                    icon: Icon(Icons.edit_outlined, size: 18, color: Colors.grey[600]),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                      padding: const EdgeInsets.all(4),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => _showQuantityDialog(context),
                    icon: Icon(Icons.inventory_outlined, size: 18, color: Colors.grey[600]),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                      padding: const EdgeInsets.all(4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showQuantityDialog(BuildContext context) {
    final TextEditingController quantityController = TextEditingController(
      text: ingredient.currentQuantity.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Adjust ${ingredient.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantity (${ingredient.unit})',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Current: ${CurrencyUtils.formatUnit(ingredient.currentQuantity, ingredient.unit)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newQuantity = double.tryParse(quantityController.text);
              if (newQuantity != null && newQuantity >= 0) {
                onQuantityChanged(newQuantity);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Update'),
          ),
        ],
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
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
                    color: _getStatusColor(session.status).withValues(alpha: 0.1),
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