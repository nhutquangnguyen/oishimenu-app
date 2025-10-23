import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/menu_item.dart';
import '../../../../models/menu_options.dart';
import '../../../menu/services/menu_service.dart';
import '../../../../services/menu_option_service.dart';
import '../../../auth/providers/auth_provider.dart';

// Vietnamese restaurant POS system - Fixed payment navigation v4

class CartItem {
  final MenuItem menuItem;
  int quantity;
  List<SelectedOption> selectedOptions;

  CartItem({
    required this.menuItem,
    this.quantity = 1,
    this.selectedOptions = const [],
  });

  double get totalPrice {
    double basePrice = menuItem.price * quantity;
    double optionsPrice = selectedOptions.fold(0.0, (sum, option) => sum + option.optionPrice) * quantity;
    return basePrice + optionsPrice;
  }

  // Helper method to get a unique identifier for cart items with different options
  String get uniqueKey {
    final optionIds = selectedOptions.map((opt) => opt.optionId).toList()..sort();
    return '${menuItem.id}_${optionIds.join('_')}';
  }
}

class PosPage extends ConsumerStatefulWidget {
  const PosPage({super.key});

  @override
  ConsumerState<PosPage> createState() => _PosPageState();
}

class _PosPageState extends ConsumerState<PosPage> {
  final MenuService _menuService = MenuService();
  final MenuOptionService _menuOptionService = MenuOptionService();
  List<MenuItem> _menuItems = [];
  Map<String, String> _categories = {};
  List<CartItem> _cartItems = [];
  String _selectedCategory = 'Tất cả';
  String _selectedTable = '';
  bool _isLoading = true;
  bool _showTableSelection = true;

  @override
  void initState() {
    super.initState();
    _loadMenuData();
  }

  Future<void> _loadMenuData() async {
    try {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final categories = await _menuService.getCategories();
      final menuItems = await _menuService.getAllMenuItems(userId: currentUser.id);

      setState(() {
        _categories = {'Tất cả': 'Tất cả', ...categories};
        _menuItems = menuItems;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading menu data: $e');
    }
  }

  List<MenuItem> get _filteredMenuItems {
    if (_selectedCategory == 'Tất cả') {
      return _menuItems;
    }
    return _menuItems.where((item) => item.categoryName == _selectedCategory).toList();
  }

  Future<void> _addToCart(MenuItem item) async {
    // Check if this menu item has linked option groups
    final optionGroups = await _menuOptionService.getOptionGroupsForMenuItem(item.id);

    if (optionGroups.isNotEmpty) {
      // Show option selection modal
      _showOptionSelectionModal(item, optionGroups);
    } else {
      // Add directly to cart without options
      _addToCartWithOptions(item, []);
    }
  }

  void _addToCartWithOptions(MenuItem item, List<SelectedOption> selectedOptions) {
    setState(() {
      // Create a cart item with the selected options
      final newCartItem = CartItem(menuItem: item, selectedOptions: selectedOptions);

      // Find existing cart item with same menu item and same options
      final existingIndex = _cartItems.indexWhere((cartItem) =>
        cartItem.menuItem.id == item.id && cartItem.uniqueKey == newCartItem.uniqueKey);

      if (existingIndex >= 0) {
        // Increase quantity of existing item with same options
        _cartItems[existingIndex].quantity++;
      } else {
        // Add new cart item
        _cartItems.add(newCartItem);
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      if (_cartItems[index].quantity > 1) {
        _cartItems[index].quantity--;
      } else {
        _cartItems.removeAt(index);
      }
    });
  }

  double get _totalAmount {
    return _cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  Widget _buildTableSelection() {
    final tables = ['Mang về', 'Bàn 1', 'Bàn 2', 'Bàn 3', 'Bàn 4', 'Bàn 5', 'Bàn 6', 'Bàn 7', 'Bàn 8', 'Grab'];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chọn bàn',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: tables.length,
              itemBuilder: (context, index) {
                final table = tables[index];
                final isSpecial = table == 'Mang về' || table == 'Grab';

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTable = table;
                      _showTableSelection = false;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isSpecial ? Icons.delivery_dining : Icons.table_restaurant,
                          size: 24,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          table,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuInterface() {
    return Column(
      children: [
        // Header with table info
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[50],
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showTableSelection = true;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.table_restaurant, size: 16, color: Colors.blue[800]),
                      const SizedBox(width: 4),
                      Text(_selectedTable, style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.w500)),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.blue[800]),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (_cartItems.isNotEmpty)
                GestureDetector(
                  onTap: _showCartBottomSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_cart, size: 16, color: Colors.green[800]),
                        const SizedBox(width: 4),
                        Text('${_cartItems.length}', style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Category filter
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories.values.elementAt(index);
              final isSelected = _selectedCategory == category;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = category;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // Menu items
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredMenuItems.isEmpty
                  ? const Center(child: Text('Không có món nào'))
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.8,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _filteredMenuItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredMenuItems[index];
                        final cartItem = _cartItems.firstWhere(
                          (cartItem) => cartItem.menuItem.id == item.id,
                          orElse: () => CartItem(menuItem: item, quantity: 0),
                        );

                        return GestureDetector(
                          onTap: () => _addToCart(item),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                    ),
                                    child: item.photos.isNotEmpty
                                        ? ClipRRect(
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                            child: Image.network(
                                              item.photos.first,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Icon(
                                                Icons.fastfood,
                                                size: 48,
                                                color: Colors.grey[400],
                                              ),
                                            ),
                                          )
                                        : Icon(
                                            Icons.fastfood,
                                            size: 48,
                                            color: Colors.grey[400],
                                          ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${item.price.toStringAsFixed(0)}đ',
                                        style: TextStyle(
                                          color: Colors.orange[700],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (cartItem.quantity > 0) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[100],
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${cartItem.quantity}',
                                            style: TextStyle(
                                              color: Colors.blue[800],
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Đơn hàng',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _cartItems.length,
                itemBuilder: (context, index) {
                  final cartItem = _cartItems[index];
                  return Card(
                    child: ListTile(
                      title: Text(cartItem.menuItem.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Base price
                          Text(
                            'Base: ${cartItem.menuItem.price.toStringAsFixed(0)}đ',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                          // Selected options
                          if (cartItem.selectedOptions.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            ...cartItem.selectedOptions.map((option) => Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '+ ${option.optionName}${option.optionPrice > 0 ? ' (+${option.optionPrice.toStringAsFixed(0)}đ)' : ''}',
                                style: TextStyle(
                                  color: Colors.orange[700],
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )),
                          ],
                          // Total price per item
                          const SizedBox(height: 4),
                          Text(
                            'Total per item: ${(cartItem.totalPrice / cartItem.quantity).toStringAsFixed(0)}đ',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _removeFromCart(index);
                              });
                              Navigator.pop(context);
                              if (_cartItems.isNotEmpty) {
                                _showCartBottomSheet();
                              }
                            },
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text('${cartItem.quantity}'),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                cartItem.quantity++;
                              });
                              Navigator.pop(context);
                              _showCartBottomSheet();
                            },
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            Row(
              children: [
                const Text(
                  'Tổng cộng:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${_totalAmount.toStringAsFixed(0)}đ',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  'Thanh toán',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _processPayment() {
    // Navigate away from cart bottom sheet first
    Navigator.pop(context);

    // Use Future.delayed to ensure the bottom sheet is fully closed before showing dialog
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Phương thức thanh toán'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.money),
                  title: const Text('Tiền mặt'),
                  onTap: () => _completePayment('Tiền mặt'),
                ),
                ListTile(
                  leading: const Icon(Icons.credit_card),
                  title: const Text('Thẻ'),
                  onTap: () => _completePayment('Thẻ'),
                ),
                ListTile(
                  leading: const Icon(Icons.account_balance),
                  title: const Text('Chuyển khoản'),
                  onTap: () => _completePayment('Chuyển khoản'),
                ),
              ],
            ),
          ),
        );
      }
    });
  }

  void _completePayment(String method) {
    // Don't pop the dialog, close it by setting state instead
    setState(() {
      _cartItems.clear();
    });

    // Close any open dialogs safely
    try {
      if (Navigator.canPop(context) && mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      // Ignore navigation errors during payment completion
      debugPrint('Navigation error during payment completion: $e');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Thanh toán thành công bằng $method'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showOptionSelectionModal(MenuItem menuItem, List<OptionGroup> optionGroups) {
    // Track selected options for each group
    Map<String, SelectedOption?> selectedOptionsMap = {};
    Map<String, List<String>> selectedMultipleOptionsMap = {};

    // Initialize selected options
    for (final group in optionGroups) {
      if (group.maxSelection > 1) {
        selectedMultipleOptionsMap[group.id] = [];
      } else {
        selectedOptionsMap[group.id] = null;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, modalSetState) {
          bool canAddToCart = true;
          String? errorMessage;

          // Validate selections
          for (final group in optionGroups) {
            if (group.isRequired) {
              if (group.maxSelection > 1) {
                final selectedCount = selectedMultipleOptionsMap[group.id]?.length ?? 0;
                if (selectedCount < group.minSelection) {
                  canAddToCart = false;
                  errorMessage = 'Please select at least ${group.minSelection} options from "${group.name}"';
                  break;
                }
              } else {
                if (selectedOptionsMap[group.id] == null) {
                  canAddToCart = false;
                  errorMessage = 'Please select an option from "${group.name}"';
                  break;
                }
              }
            }
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Text(
                        menuItem.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      if (menuItem.description?.isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        Text(
                          menuItem.description!,
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        '${menuItem.price.toStringAsFixed(0)}đ',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Option groups
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: optionGroups.length,
                    itemBuilder: (context, groupIndex) {
                      final group = optionGroups[groupIndex];
                      final isMultiple = group.maxSelection > 1;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Group header
                            Container(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          group.name,
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      if (group.isRequired)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'REQUIRED',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (group.description?.isNotEmpty == true) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      group.description!,
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    isMultiple
                                        ? 'Select ${group.minSelection} to ${group.maxSelection} options'
                                        : 'Select 1 option',
                                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                  ),
                                ],
                              ),
                            ),

                            // Options
                            ...group.options.asMap().entries.map((entry) {
                              final optionIndex = entry.key;
                              final option = entry.value;

                              return Container(
                                decoration: BoxDecoration(
                                  border: optionIndex > 0 ? Border(top: BorderSide(color: Colors.grey[200]!)) : null,
                                ),
                                child: isMultiple
                                    ? CheckboxListTile(
                                        title: Text(option.name),
                                        subtitle: option.price > 0 ? Text('+${option.price.toStringAsFixed(0)}đ') : null,
                                        value: selectedMultipleOptionsMap[group.id]?.contains(option.id) ?? false,
                                        onChanged: (value) {
                                          modalSetState(() {
                                            final currentSelections = selectedMultipleOptionsMap[group.id] ?? [];
                                            if (value == true) {
                                              if (currentSelections.length < group.maxSelection) {
                                                selectedMultipleOptionsMap[group.id] = [...currentSelections, option.id];
                                              }
                                            } else {
                                              selectedMultipleOptionsMap[group.id] = currentSelections.where((id) => id != option.id).toList();
                                            }
                                          });
                                        },
                                        activeColor: Colors.green[600],
                                        controlAffinity: ListTileControlAffinity.trailing,
                                      )
                                    : RadioListTile<String>(
                                        title: Text(option.name),
                                        subtitle: option.price > 0 ? Text('+${option.price.toStringAsFixed(0)}đ') : null,
                                        value: option.id,
                                        groupValue: selectedOptionsMap[group.id]?.optionId,
                                        onChanged: (value) {
                                          modalSetState(() {
                                            selectedOptionsMap[group.id] = SelectedOption(
                                              optionGroupId: group.id,
                                              optionGroupName: group.name,
                                              optionId: option.id,
                                              optionName: option.name,
                                              optionPrice: option.price,
                                            );
                                          });
                                        },
                                        activeColor: Colors.green[600],
                                      ),
                              );
                            }).toList(),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Error message
                if (errorMessage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Add to cart button
                Container(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: canAddToCart ? () {
                        // Collect all selected options
                        List<SelectedOption> selectedOptions = [];

                        // Add single selections
                        selectedOptionsMap.forEach((groupId, selectedOption) {
                          if (selectedOption != null) {
                            selectedOptions.add(selectedOption);
                          }
                        });

                        // Add multiple selections
                        selectedMultipleOptionsMap.forEach((groupId, selectedOptionIds) {
                          final group = optionGroups.firstWhere((g) => g.id == groupId);
                          for (final optionId in selectedOptionIds) {
                            final option = group.options.firstWhere((o) => o.id == optionId);
                            selectedOptions.add(SelectedOption(
                              optionGroupId: groupId,
                              optionGroupName: group.name,
                              optionId: option.id,
                              optionName: option.name,
                              optionPrice: option.price,
                            ));
                          }
                        });

                        Navigator.pop(context);
                        _addToCartWithOptions(menuItem, selectedOptions);
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Add to Cart'),
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

  @override
  Widget build(BuildContext context) {
    if (_showTableSelection) {
      return Scaffold(
        body: _buildTableSelection(),
      );
    }

    return Scaffold(
      body: _buildMenuInterface(),
    );
  }
}