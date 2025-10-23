import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../models/menu_item.dart';
import '../../../../models/menu_options.dart';
import '../../services/menu_service.dart';
import '../../../../services/menu_option_service.dart';
import '../widgets/menu_item_card.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/providers/auth_provider.dart';

class MenuPage extends ConsumerStatefulWidget {
  const MenuPage({super.key});

  @override
  ConsumerState<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends ConsumerState<MenuPage> with TickerProviderStateMixin {
  late TabController _tabController;
  final MenuService _menuService = MenuService();
  final MenuOptionService _menuOptionService = MenuOptionService();

  List<MenuItem> _menuItems = [];
  Map<String, String> _categories = {};
  List<OptionGroup> _optionGroups = [];
  bool _isLoading = true;
  Map<String, bool> _expandedCategories = {};
  Map<String, bool> _expandedOptionGroups = {};
  int _currentTabIndex = 0; // Track tab state independently
  bool _isNavigating = false; // Prevent double navigation

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadMenuData();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    }
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
        setState(() {
          _currentTabIndex = tabIndex;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMenuData() async {
    final currentTabIndex = _tabController.index; // Preserve current tab
    setState(() => _isLoading = true);
    try {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final menuItems = await _menuService.getAllMenuItems(userId: currentUser.id);
      final categories = await _menuService.getCategories();
      final optionGroups = await _menuOptionService.getAllOptionGroups();

      setState(() {
        _menuItems = menuItems;
        _categories = categories;
        _optionGroups = optionGroups;
        _isLoading = false;
      });

      // Restore the original tab index
      if (_tabController.index != currentTabIndex) {
        _tabController.index = currentTabIndex;
      }
    } catch (e) {
      print('Error loading menu data: $e');
      setState(() => _isLoading = false);
    }
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
              tabs: [
                Tab(text: AppLocalizations.menuItems),
                Tab(text: AppLocalizations.menuOptionGroups),
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
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton(
              onPressed: _showAddOptions,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildItemsTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Initialize all categories (including empty ones)
    Map<String, List<MenuItem>> itemsByCategory = {};

    // First, create entries for all categories
    for (final categoryName in _categories.values) {
      itemsByCategory[categoryName] = [];
    }

    // Then add menu items to their respective categories
    for (var item in _menuItems) {
      if (itemsByCategory.containsKey(item.categoryName)) {
        itemsByCategory[item.categoryName]!.add(item);
      } else {
        // Handle items with categories not in our categories list
        itemsByCategory[item.categoryName] = [item];
      }
    }

    if (_categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No categories yet',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first category to get started',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMenuData,
      child: _buildDraggableView(),
    );
  }

  Widget _buildDraggableView() {
    return FutureBuilder<List<MenuCategory>>(
      future: _menuService.getCategoriesOrdered(),
      builder: (context, categorySnapshot) {
        if (!categorySnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final orderedCategories = categorySnapshot.data!;

        return ReorderableListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: orderedCategories.length,
          buildDefaultDragHandles: false, // Disable default drag handles
          onReorder: (oldIndex, newIndex) => _reorderCategories(oldIndex, newIndex, orderedCategories),
          itemBuilder: (context, index) {
            final category = orderedCategories[index];
            final categoryItems = _menuItems.where((item) =>
              item.categoryName == category.name
            ).toList();
            final isExpanded = _expandedCategories[category.name] ?? true;

            return _buildDraggableCategorySection(
              key: ValueKey(category.id),
              category: category,
              items: categoryItems,
              isExpanded: isExpanded,
              index: index,
            );
          },
        );
      },
    );
  }

  Widget _buildDraggableCategorySection({
    required Key key,
    required MenuCategory category,
    required List<MenuItem> items,
    required bool isExpanded,
    required int index,
  }) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Header with drag handle
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              // Drag handle for categories
              ReorderableDragStartListener(
                index: index,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.drag_handle,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _expandedCategories[category.name] = !isExpanded;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            category.name.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Icon(
                          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Category Items
        if (isExpanded) ...[
          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              margin: const EdgeInsets.only(bottom: 4, left: 28),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.restaurant_menu_outlined,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No items in this category yet',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              margin: const EdgeInsets.only(left: 28),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                buildDefaultDragHandles: false,
                onReorder: (oldIndex, newIndex) => _reorderMenuItems(oldIndex, newIndex, items, category),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Container(
                    key: ValueKey('${item.id}_${category.id}_item'),
                    margin: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        // Drag handle for menu items
                        ReorderableDragStartListener(
                          index: index,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.drag_indicator,
                              color: Colors.grey[400],
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: MenuItemCard(
                            menuItem: item,
                            categoryName: category.name,
                            onTap: () => _editMenuItem(item),
                            onToggleAvailability: () => _toggleAvailability(item),
                            onDelete: () => _deleteMenuItem(item),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }


  Widget _buildOptionGroupsTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final filteredGroups = _optionGroups;

    if (filteredGroups.isEmpty) {
      final iconData = Icons.tune_outlined;
      final title = 'Chưa có nhóm tùy chọn';
      final subtitle = 'Thêm nhóm tùy chọn đầu tiên của bạn';

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
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddOptionGroupDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Thêm nhóm tùy chọn'),
            ),
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
            Text(AppLocalizations.menuCategory(categoryName)),
            const SizedBox(height: 8),
            if (menuItem.description?.isNotEmpty == true)
              Text(AppLocalizations.menuDescription(menuItem.description)),
            const SizedBox(height: 8),
            Text(AppLocalizations.menuPrice(menuItem.price.toStringAsFixed(2))),
            if (menuItem.costPrice != null)
              Text(AppLocalizations.menuCost(menuItem.costPrice!.toStringAsFixed(2))),
            const SizedBox(height: 8),
            Text(AppLocalizations.menuStatus(menuItem.availableStatus ? AppLocalizations.menuAvailableStatus : AppLocalizations.menuUnavailableStatus)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.menuClose),
          ),
        ],
      ),
    );
  }

  void _toggleAvailability(MenuItem menuItem) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    await _menuService.updateMenuItemStatus(menuItem.id, !menuItem.availableStatus, userId: currentUser.id);
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
            SnackBar(content: Text(AppLocalizations.menuFailedUpdateOptionAvailability)),
          );
        }
      }
    } catch (e) {
      print('Error toggling option availability: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.menuErrorUpdatingOptionAvailability)),
        );
      }
    }
  }

  void _showEditMenuItemDialog(MenuItem menuItem) {
    // TODO: Implement edit menu item dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.menuEditComingSoon)),
    );
  }

  void _showDeleteConfirmation(MenuItem menuItem) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.menuDeleteMenuItem),
        content: Text(AppLocalizations.menuDeleteConfirmation(menuItem.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final currentUser = ref.read(currentUserProvider);
              if (currentUser != null) {
                await _menuService.deleteMenuItem(menuItem.id, userId: currentUser.id);
                await _loadMenuData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${menuItem.name} deleted')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.menuDelete),
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
    if (_isNavigating) return; // Prevent double navigation

    _isNavigating = true;
    try {
      // Navigate to edit screen and wait for result
      final result = await context.push('/menu/items/${item.id}/edit');
      // If the menu item was successfully updated, refresh the data
      if (result == true && mounted) {
        await _loadMenuData();
      }
    } finally {
      _isNavigating = false;
    }
  }

  Future<void> _toggleMenuItemAvailability(MenuItem item) async {
    try {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) return;

      await _menuService.updateMenuItemStatus(item.id, !item.availableStatus, userId: currentUser.id);
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
            child: Text(AppLocalizations.cancel),
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
        final currentUser = ref.read(currentUserProvider);
        if (currentUser != null) {
          await _menuService.deleteMenuItem(item.id, userId: currentUser.id);
          await _loadMenuData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Menu item deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
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
    if (_isNavigating) return; // Prevent double navigation

    _isNavigating = true;
    try {
      // Navigate to edit screen and wait for result
      final result = await context.push('/menu/option-groups/${group.id}/edit?from=menu');

      // If the option group was successfully updated, refresh the data
      if (result == true && mounted) {
        await _loadMenuData();
      }
    } finally {
      _isNavigating = false;
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
            child: Text(AppLocalizations.menuClose),
          ),
        ],
      ),
    );
  }

  void _showAddOptions() {
    if (_isNavigating) return; // Prevent double navigation

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isDismissible: true,
      enableDrag: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Add New',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.restaurant_menu, color: Colors.green[600]),
              ),
              title: const Text('Add Menu Item'),
              subtitle: const Text('Add a new item to your menu'),
              onTap: () {
                Navigator.pop(context);
                // Small delay to ensure modal dismissal completes
                Future.delayed(const Duration(milliseconds: 50), () {
                  if (mounted) _addMenuItem();
                });
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.category, color: Colors.blue[600]),
              ),
              title: const Text('Add Category'),
              subtitle: const Text('Create a new category for your items'),
              onTap: () {
                Navigator.pop(context);
                // Small delay to ensure modal dismissal completes
                Future.delayed(const Duration(milliseconds: 50), () {
                  if (mounted) _addCategory();
                });
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _addCategory() async {
    if (!mounted) return;

    try {
      String? categoryName = await showDialog<String>(
        context: context,
        barrierDismissible: true,
        useRootNavigator: true,
        builder: (dialogContext) => _buildAddCategoryDialog(),
      );

      if (categoryName != null && categoryName.trim().isNotEmpty && mounted) {
        try {
          final category = MenuCategory(
            id: '',
            name: categoryName.trim(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          final result = await _menuService.createCategory(category);
          if (result != null && mounted) {
            await _loadMenuData();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Category "$categoryName" created successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error creating category: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      // Error already handled in inner try-catch
    }
  }

  Widget _buildAddCategoryDialog() {
    final controller = TextEditingController();

    return AlertDialog(
      title: const Text('Add New Category'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          hintText: 'Enter category name',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            Navigator.of(context, rootNavigator: true).pop(value.trim());
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final text = controller.text.trim();
            if (text.isNotEmpty) {
              Navigator.of(context, rootNavigator: true).pop(text);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }

  Future<void> _addMenuItem() async {
    if (_isNavigating) return; // Prevent double navigation

    _isNavigating = true;
    try {
      // Navigate to add new menu item page and wait for result
      final result = await context.push('/menu/items/new');

      // If the menu item was successfully created, refresh the data
      if (result == true && mounted) {
        await _loadMenuData();
      }
    } finally {
      _isNavigating = false;
    }
  }

  // Reordering methods
  Future<void> _reorderCategories(int oldIndex, int newIndex, List<MenuCategory> categories) async {
    try {
      setState(() => _isLoading = true);

      // Adjust newIndex for the standard behavior expected by ReorderableListView
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

      // Create a new list with reordered categories
      final List<MenuCategory> reorderedCategories = List.from(categories);
      final MenuCategory movedCategory = reorderedCategories.removeAt(oldIndex);
      reorderedCategories.insert(newIndex, movedCategory);

      // Update the service with the new order
      final success = await _menuService.reorderCategories(reorderedCategories);

      if (success) {
        // Refresh the data to reflect the changes
        await _loadMenuData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Category order updated successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update category order'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error reordering categories: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reordering categories: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _reorderMenuItems(int oldIndex, int newIndex, List<MenuItem> items, MenuCategory category) async {
    try {
      setState(() => _isLoading = true);

      // Adjust newIndex for the standard behavior expected by ReorderableListView
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

      // Create a new list with reordered menu items
      final List<MenuItem> reorderedItems = List.from(items);
      final MenuItem movedItem = reorderedItems.removeAt(oldIndex);
      reorderedItems.insert(newIndex, movedItem);

      // Update the service with the new order
      final categoryId = int.tryParse(category.id) ?? 0;
      final success = await _menuService.reorderMenuItems(reorderedItems, categoryId);

      if (success) {
        // Refresh the data to reflect the changes
        await _loadMenuData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Menu item order updated successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update menu item order'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error reordering menu items: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reordering menu items: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Item reordering dialog
  void _showItemReorderDialog(MenuItem item, MenuCategory category, List<MenuItem> items) {
    final currentIndex = items.indexOf(item);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reorder "${item.name}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current position: ${currentIndex + 1} of ${items.length}'),
            const SizedBox(height: 16),
            Text('Choose new position:', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              width: double.maxFinite,
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final isCurrentPosition = index == currentIndex;
                  return ListTile(
                    leading: Text('${index + 1}'),
                    title: Text(
                      index == currentIndex ? item.name : items[index].name,
                      style: TextStyle(
                        fontWeight: isCurrentPosition ? FontWeight.bold : FontWeight.normal,
                        color: isCurrentPosition ? Theme.of(context).colorScheme.primary : null,
                      ),
                    ),
                    trailing: isCurrentPosition
                      ? Icon(Icons.my_location, color: Theme.of(context).colorScheme.primary)
                      : null,
                    onTap: isCurrentPosition ? null : () {
                      Navigator.pop(context);
                      _moveItemToPosition(item, category, currentIndex, index);
                    },
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _moveItemToPosition(MenuItem item, MenuCategory category, int oldIndex, int newIndex) async {
    try {
      setState(() => _isLoading = true);

      // Get all items in this category
      final categoryItems = _menuItems.where((i) => i.categoryName == category.name).toList();

      // Create reordered list
      final reorderedItems = List<MenuItem>.from(categoryItems);
      reorderedItems.removeAt(oldIndex);
      reorderedItems.insert(newIndex, item);

      // Update the service with the new order
      final categoryId = int.tryParse(category.id) ?? 0;
      final success = await _menuService.reorderMenuItems(reorderedItems, categoryId);

      if (success) {
        await _loadMenuData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Moved "${item.name}" to position ${newIndex + 1}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to reorder menu item'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error moving menu item: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reordering item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}