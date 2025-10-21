import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if we should show a specific tab from query parameter
    final state = GoRouterState.of(context);
    final tabParam = state.uri.queryParameters['tab'];
    if (tabParam != null) {
      final tabIndex = int.tryParse(tabParam) ?? 0;
      if (tabIndex >= 0 && tabIndex < 2) {
        _tabController.animateTo(tabIndex);
      }
    }
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
            child: Column(
              children: [
                Row(
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
                    // Scan button
                    GestureDetector(
                      onTap: _goToScanMenu,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          border: Border.all(color: Colors.blue[300]!),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Icon(
                          Icons.qr_code_scanner,
                          color: Colors.blue[600],
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
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
                ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 16),
                  child: MenuItemCard(
                    menuItem: item,
                    categoryName: categoryName,
                    onTap: () => _editMenuItem(item),
                    onToggleAvailability: () => _toggleAvailability(item),
                    onEdit: () => _editMenuItem(item),
                    onDelete: () => _deleteMenuItem(item),
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

    // Filter option groups based on search query
    final filteredGroups = _searchQuery.isEmpty
        ? _optionGroups
        : _optionGroups.where((group) {
            final query = _searchQuery.toLowerCase();
            final matchesName = group.name.toLowerCase().contains(query);
            final matchesDescription = group.description?.toLowerCase().contains(query) ?? false;
            final matchesOptions = group.options.any((option) =>
                option.name.toLowerCase().contains(query));
            return matchesName || matchesDescription || matchesOptions;
          }).toList();

    if (filteredGroups.isEmpty) {
      final isSearchEmpty = _searchQuery.isEmpty;
      final iconData = isSearchEmpty ? Icons.tune_outlined : Icons.search_off;
      final title = isSearchEmpty ? 'Chưa có nhóm tùy chọn' : 'Không tìm thấy';
      final subtitle = isSearchEmpty
          ? 'Thêm nhóm tùy chọn đầu tiên của bạn'
          : 'Thử từ khóa tìm kiếm khác';

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(iconData, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.grey),
            ),
            if (isSearchEmpty) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _showAddOptionGroupDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Thêm nhóm tùy chọn'),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMenuData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: filteredGroups.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final group = filteredGroups[index];
          return _buildOptionGroupCard(group);
        },
      ),
    );
  }

  Widget _buildOptionGroupCard(OptionGroup group) {
    final isExpanded = _expandedOptionGroups[group.id] ?? false;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                group.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (group.isRequired)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                margin: const EdgeInsets.only(left: 8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'BẮT BUỘC',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${group.options.length} tùy chọn • Tối thiểu: ${group.minSelection} • Tối đa: ${group.maxSelection}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        if (group.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            group.description!,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Action buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _editOptionGroup(group),
                        icon: const Icon(Icons.edit, size: 20),
                        color: Colors.blue,
                        tooltip: 'Chỉnh sửa',
                      ),
                      IconButton(
                        onPressed: () => _showDeleteConfirmationForOptionGroup(group),
                        icon: const Icon(Icons.delete, size: 20),
                        color: Colors.red,
                        tooltip: 'Xóa',
                      ),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Option Items (when expanded)
          if (isExpanded) ...[
            const Divider(height: 1),
            if (group.options.isNotEmpty)
              ...group.options.map((option) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey[200]!),
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
                          if (option.description?.isNotEmpty == true) ...[
                            const SizedBox(height: 2),
                            Text(
                              option.description!,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (option.price > 0) ...[
                      Text(
                        '+${option.price.toStringAsFixed(0)}đ',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Switch(
                      value: option.isAvailable,
                      onChanged: (value) async {
                        await _toggleOptionAvailability(option, value);
                      },
                      activeColor: Colors.green,
                    ),
                  ],
                ),
              ))
            else
              Container(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Chưa có tùy chọn nào trong nhóm này',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
          ],
        ],
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

  Future<void> _showAddMenuItemDialog() async {
    // Navigate to the new menu item editor
    final result = await context.push('/menu/items/new');
    // If the menu item was successfully created, refresh the data
    if (result == true && mounted) {
      await _loadMenuData();
    }
  }

  Future<void> _editMenuItem(MenuItem item) async {
    // Navigate to edit screen and wait for result
    final result = await context.push('/menu/items/${item.id}/edit');
    // If the menu item was successfully updated, refresh the data
    if (result == true && mounted) {
      await _loadMenuData();
    }
  }

  Future<void> _toggleMenuItemAvailability(MenuItem item) async {
    try {
      await _menuService.updateMenuItemStatus(item.id, !item.availableStatus);
      // Refresh the data to show the updated availability
      await _loadMenuData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating availability: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteMenuItem(MenuItem item) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Menu Item'),
        content: Text('Are you sure you want to delete "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _menuService.deleteMenuItem(item.id);
        await _loadMenuData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Menu item deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting item: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showAddOptionGroupDialog() async {
    // Navigate to dedicated option groups management page and wait for result
    final result = await context.push('/menu/option-groups/new');

    // If the option group was successfully created, refresh the data
    if (result == true && mounted) {
      await _loadMenuData();
    }
  }

  Future<void> _editOptionGroup(OptionGroup group) async {
    // Navigate to edit screen and wait for result
    final result = await context.push('/menu/option-groups/${group.id}/edit?from=menu');

    // If the option group was successfully updated, refresh the data
    if (result == true && mounted) {
      await _loadMenuData();
    }
  }

  void _showEditOptionGroupDialog(OptionGroup group) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Chỉnh sửa nhóm tùy chọn ⚡'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Đang chỉnh sửa: "${group.name}"'),
              const SizedBox(height: 16),
              Text(
                'Tính năng chỉnh sửa đang được phát triển.\nHiện tại bạn có thể xem và quản lý các nhóm tùy chọn.',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Open full editor in the future
              // For now, navigate to dedicated editor if needed
              context.go('/menu/option-groups/${group.id}/edit');
            },
            child: const Text('Mở trình chỉnh sửa'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationForOptionGroup(OptionGroup group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa nhóm tùy chọn'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bạn có chắc chắn muốn xóa "${group.name}"?'),
            const SizedBox(height: 8),
            Text(
              'Hành động này không thể hoàn tác.',
              style: TextStyle(
                color: Colors.red[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteOptionGroup(group);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteOptionGroup(OptionGroup group) async {
    try {
      final success = await _menuOptionService.deleteOptionGroup(group.id);

      if (mounted) {
        if (success) {
          // Refresh the option groups list
          await _loadMenuData();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã xóa "${group.name}"'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi xóa "${group.name}"'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  Future<void> _goToScanMenu() async {
    // Navigate to scan menu page and wait for result
    final result = await context.push('/menu/scan');

    // If items were successfully imported, refresh the data
    if (result == true && mounted) {
      await _loadMenuData();
    }
  }
}