import 'package:flutter/material.dart';
import '../../../../models/menu_item.dart';
import '../../../../models/menu_options.dart';
import '../../services/menu_service.dart';
import '../../../../services/menu_option_service.dart';
import '../widgets/menu_item_card.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> with TickerProviderStateMixin {
  late TabController _tabController;
  final MenuService _menuService = MenuService();
  final MenuOptionService _menuOptionService = MenuOptionService();

  List<MenuItem> _menuItems = [];
  Map<String, String> _categories = {};
  List<OptionGroup> _optionGroups = [];
  bool _isLoading = true;
  String _searchQuery = '';
  Map<String, bool> _expandedCategories = {};
  Map<String, bool> _expandedOptionGroups = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMenuData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMenuData() async {
    setState(() => _isLoading = true);
    try {
      final menuItems = await _menuService.getAllMenuItems();
      final categories = await _menuService.getCategories();
      final optionGroups = await _menuOptionService.getAllOptionGroups();

      setState(() {
        _menuItems = menuItems;
        _categories = categories;
        _optionGroups = optionGroups;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading menu data: $e');
      setState(() => _isLoading = false);
    }
  }

  List<MenuItem> get _filteredMenuItems {
    if (_searchQuery.isEmpty) return _menuItems;
    return _menuItems.where((item) {
      return item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             (item.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).colorScheme.primary,
              tabs: const [
                Tab(text: 'Items'),
                Tab(text: 'Option Groups'),
              ],
            ),
          ),
          // Search and filter bar
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Out of Stock (12)'),
                      const SizedBox(width: 8),
                      Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule, size: 16),
                      const SizedBox(width: 4),
                      const Text('Availability'),
                      const SizedBox(width: 8),
                      Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildItemsTab(),
                _buildOptionGroupsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
            // Add new menu item
            _showAddMenuItemDialog();
          } else {
            // Add new option group
            _showAddOptionGroupDialog();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildItemsTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Group menu items by category
    Map<String, List<MenuItem>> itemsByCategory = {};
    for (var item in _filteredMenuItems) {
      if (!itemsByCategory.containsKey(item.categoryName)) {
        itemsByCategory[item.categoryName] = [];
      }
      itemsByCategory[item.categoryName]!.add(item);
    }

    if (itemsByCategory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.restaurant_menu_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'No items found' : 'No menu items yet',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Add your first menu item to get started',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMenuData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: itemsByCategory.entries.map((entry) {
          final categoryName = entry.key;
          final items = entry.value;
          final isExpanded = _expandedCategories[categoryName] ?? true;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Header
              InkWell(
                onTap: () {
                  setState(() {
                    _expandedCategories[categoryName] = !isExpanded;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          categoryName.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ),
              ),
              // Category Items
              if (isExpanded)
                ...items.map((item) => Container(
                  margin: const EdgeInsets.only(bottom: 8, left: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      if (item.photos.isNotEmpty)
                        Container(
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.fastfood, color: Colors.grey),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${item.price.toStringAsFixed(0)}đ',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: item.availableStatus,
                        onChanged: (_) => _toggleAvailability(item),
                        activeColor: Colors.green,
                      ),
                    ],
                  ),
                )),
              const SizedBox(height: 16),
            ],
          );
        }).toList(),
      ),
    );
  }


  Widget _buildOptionGroupsTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_optionGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.tune_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No option groups yet',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first option group to get started',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMenuData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _optionGroups.length,
        itemBuilder: (context, index) {
          final group = _optionGroups[index];
          final isExpanded = _expandedOptionGroups[group.id] ?? false;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                // Option Group Header
                InkWell(
                  onTap: () {
                    setState(() {
                      _expandedOptionGroups[group.id] = !isExpanded;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${group.options.length} options • Min: ${group.minSelection} • Max: ${group.maxSelection}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              if (group.description?.isNotEmpty == true)
                                Text(
                                  group.description!,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (group.isRequired)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'REQUIRED',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        Icon(
                          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                ),
                // Option Items
                if (isExpanded && group.options.isNotEmpty)
                  ...group.options.map((option) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (option.description?.isNotEmpty == true)
                                Text(
                                  option.description!,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              if (option.category?.isNotEmpty == true)
                                Text(
                                  'Category: ${option.category}',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (option.price > 0)
                          Text(
                            '+${option.price.toStringAsFixed(0)}đ',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        const SizedBox(width: 12),
                        Switch(
                          value: option.isAvailable,
                          onChanged: (value) async {
                            // Toggle option availability
                            await _toggleOptionAvailability(option, value);
                          },
                          activeColor: Colors.green,
                        ),
                      ],
                    ),
                  )),
                if (isExpanded && group.options.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'No options in this group',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper methods
  void _showMenuItemDetails(MenuItem menuItem, String categoryName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(menuItem.name),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Category: $categoryName'),
            const SizedBox(height: 8),
            if (menuItem.description?.isNotEmpty == true)
              Text('Description: ${menuItem.description}'),
            const SizedBox(height: 8),
            Text('Price: ₫${menuItem.price.toStringAsFixed(2)}'),
            if (menuItem.costPrice != null)
              Text('Cost: ₫${menuItem.costPrice!.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            Text('Status: ${menuItem.availableStatus ? "Available" : "Unavailable"}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _toggleAvailability(MenuItem menuItem) async {
    await _menuService.updateMenuItemStatus(menuItem.id, !menuItem.availableStatus);
    await _loadMenuData();
  }

  Future<void> _toggleOptionAvailability(MenuOption option, bool newValue) async {
    try {
      final updatedOption = option.copyWith(
        isAvailable: newValue,
        updatedAt: DateTime.now(),
      );

      final success = await _menuOptionService.updateMenuOption(updatedOption);
      if (success) {
        await _loadMenuData();
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update option availability')),
          );
        }
      }
    } catch (e) {
      print('Error toggling option availability: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error updating option availability')),
        );
      }
    }
  }

  void _showEditMenuItemDialog(MenuItem menuItem) {
    // TODO: Implement edit menu item dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit menu item - Coming soon!')),
    );
  }

  void _showDeleteConfirmation(MenuItem menuItem) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Menu Item'),
        content: Text('Are you sure you want to delete "${menuItem.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _menuService.deleteMenuItem(menuItem.id);
              await _loadMenuData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${menuItem.name} deleted')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddMenuItemDialog() {
    // TODO: Implement add menu item dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add menu item - Coming soon!')),
    );
  }

  void _showAddOptionGroupDialog() {
    // TODO: Implement add option group dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add option group - Coming soon!')),
    );
  }

  void _showCategoryItems(String categoryId, String categoryName) {
    final categoryItems = _menuItems.where((item) => item.categoryName == categoryName).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(categoryName),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: categoryItems.length,
            itemBuilder: (context, index) {
              final item = categoryItems[index];
              return ListTile(
                title: Text(item.name),
                subtitle: Text('₫${item.price.toStringAsFixed(2)}'),
                trailing: Icon(
                  item.availableStatus ? Icons.check_circle : Icons.cancel,
                  color: item.availableStatus ? Colors.green : Colors.red,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}