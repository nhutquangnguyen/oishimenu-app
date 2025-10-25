import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../models/menu_item.dart';
import '../../../../models/menu_options.dart';
import '../../../../models/customer.dart';
import '../../../../models/order.dart' as order_model;
import '../../../menu/services/menu_service.dart';
import '../../../../services/menu_option_service.dart';
import '../../../../services/order_service.dart';
import '../../../../services/customer_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../checkout/presentation/pages/checkout_page.dart';

// Vietnamese restaurant POS system - Fixed payment navigation v4

class CartItem {
  final MenuItem menuItem;
  int quantity;
  List<SelectedOption> selectedOptions;
  String? notes; // Notes for individual item

  CartItem({
    required this.menuItem,
    this.quantity = 1,
    this.selectedOptions = const [],
    this.notes,
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
  final order_model.Order? existingOrder;

  const PosPage({super.key, this.existingOrder});

  @override
  ConsumerState<PosPage> createState() => _PosPageState();
}

class _PosPageState extends ConsumerState<PosPage> {
  final MenuService _menuService = MenuService();
  final MenuOptionService _menuOptionService = MenuOptionService();
  final OrderService _orderService = OrderService();
  final CustomerService _customerService = CustomerService();
  final TextEditingController _searchController = TextEditingController();
  List<MenuItem> _menuItems = [];
  List<CartItem> _cartItems = [];
  String _searchQuery = '';
  String? _selectedCategory; // null means "All"
  String _selectedTable = 'pos_page.default_table'.tr();
  Customer? _selectedCustomer;
  bool _isLoading = true;
  String _orderNotes = ''; // Order notes/comments

  // Text controllers for persistent form fields
  late TextEditingController _orderNotesController;
  late TextEditingController _customerPhoneController;
  late TextEditingController _customerNameController;

  // Track if we're editing an existing order
  String? _existingOrderId;
  String? _existingOrderNumber;
  DateTime? _existingOrderCreatedAt;

  // Track if we're in save order mode (allows incomplete selections)
  bool _isInSaveOrderMode = false;

  @override
  void initState() {
    super.initState();
    _orderNotesController = TextEditingController(text: _orderNotes);
    _loadMenuData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _orderNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadMenuData() async {
    try {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final menuItems = await _menuService.getAllMenuItems(userId: currentUser.id);

      setState(() {
        _menuItems = menuItems;
        _isLoading = false;
      });

      // Load existing order if provided
      if (widget.existingOrder != null) {
        _loadExistingOrder(widget.existingOrder!);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading menu data: $e');
    }
  }

  // Store additional order details to preserve when saving
  order_model.OrderType? _originalOrderType;
  String? _originalPlatform;
  order_model.PaymentMethod? _originalPaymentMethod;
  order_model.PaymentStatus? _originalPaymentStatus;
  double? _originalDiscount;
  double? _originalTax;
  double? _originalServiceCharge;
  double? _originalDeliveryFee;

  void _loadExistingOrder(order_model.Order order) {
    // Convert order items to cart items
    final cartItems = <CartItem>[];

    for (final orderItem in order.items) {
      // Find the menu item from loaded menu items
      final menuItem = _menuItems.firstWhere(
        (item) => item.id == orderItem.menuItemId,
        orElse: () => MenuItem(
          id: orderItem.menuItemId,
          name: orderItem.menuItemName,
          price: orderItem.basePrice,
          categoryName: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Convert order selected options to POS selected options
      final selectedOptions = orderItem.selectedOptions.map((opt) {
        return SelectedOption(
          optionGroupId: opt.optionGroupId,
          optionGroupName: opt.optionGroupName,
          optionId: opt.optionId,
          optionName: opt.optionName,
          optionPrice: opt.price,
        );
      }).toList();

      cartItems.add(CartItem(
        menuItem: menuItem,
        quantity: orderItem.quantity,
        selectedOptions: selectedOptions,
        notes: orderItem.notes,
      ));
    }

    setState(() {
      _cartItems = cartItems;
      _selectedTable = order.tableNumber ?? 'pos_page.default_table'.tr();
      _selectedCustomer = Customer(
        id: order.customer.id,
        name: order.customer.name,
        phone: order.customer.phone ?? '',
        email: order.customer.email ?? '',
        address: order.customer.address ?? '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      // Store the existing order ID, number, and creation time for updates
      _existingOrderId = order.id;
      _existingOrderNumber = order.orderNumber;
      _existingOrderCreatedAt = order.createdAt;
      // Load existing notes
      _orderNotes = order.notes ?? '';
      _orderNotesController.text = _orderNotes;

      // Preserve original order details for saving
      _originalOrderType = order.orderType;
      _originalPlatform = order.platform;
      _originalPaymentMethod = order.paymentMethod;
      _originalPaymentStatus = order.paymentStatus;
      _originalDiscount = order.discount;
      _originalTax = order.tax;
      _originalServiceCharge = order.serviceCharge;
      _originalDeliveryFee = order.deliveryFee;
    });
  }

  // Get list of available categories (non-empty)
  List<String> get _availableCategories {
    final categories = <String>{};
    for (var item in _menuItems) {
      categories.add(item.categoryName);
    }
    return categories.toList()..sort();
  }

  List<MenuItem> get _filteredMenuItems {
    var items = _menuItems;

    // Filter by category
    if (_selectedCategory != null) {
      items = items.where((item) => item.categoryName == _selectedCategory).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      items = items.where((item) {
        final searchLower = _searchQuery.toLowerCase();
        return item.name.toLowerCase().contains(searchLower) ||
               item.description.toLowerCase().contains(searchLower) ||
               item.categoryName.toLowerCase().contains(searchLower);
      }).toList();
    }

    return items;
  }

  // Group items by category for sectioned display
  Map<String, List<MenuItem>> get _itemsByCategory {
    final Map<String, List<MenuItem>> grouped = {};

    for (var item in _filteredMenuItems) {
      if (!grouped.containsKey(item.categoryName)) {
        grouped[item.categoryName] = [];
      }
      grouped[item.categoryName]!.add(item);
    }

    return grouped;
  }

  // Get top 5 ordered items (simplified - using cart frequency as proxy)
  List<MenuItem> get _hotItems {
    // For now, return first 5 items as hot items
    // In a real app, this would query order history
    return _filteredMenuItems.take(5).toList();
  }

  Future<void> _addToCart(MenuItem item) async {
    // Check if this menu item has linked option groups
    final optionGroups = await _menuOptionService.getOptionGroupsForMenuItem(item.id);

    if (optionGroups.isNotEmpty) {
      // Show option selection modal, skip validation if in save order mode
      _showOptionSelectionModal(item, optionGroups, skipValidation: _isInSaveOrderMode);
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

  Widget _buildCategorizedItemsList() {
    final itemsByCategory = _itemsByCategory;
    final hotItems = _searchQuery.isEmpty ? _hotItems : <MenuItem>[];

    return CustomScrollView(
      slivers: [
        // Hot Items Section (only show when not searching)
        if (hotItems.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.local_fire_department, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'pos_page.hot_items'.tr(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildCompactMenuItem(hotItems[index]),
                ),
                childCount: hotItems.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],

        // Category Sections
        ...itemsByCategory.entries.map((entry) {
          final categoryName = entry.key;
          final items = entry.value;

          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  categoryName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildCompactMenuItem(items[index]),
                  ),
                  childCount: items.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ];
        }).expand((widget) => widget),

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildCompactMenuItem(MenuItem item) {
    final cartItem = _cartItems.firstWhere(
      (cartItem) => cartItem.menuItem.id == item.id,
      orElse: () => CartItem(menuItem: item, quantity: 0),
    );

    return GestureDetector(
      onTap: () => _addToCart(item),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            // Item image
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
              ),
              child: item.photos.isNotEmpty
                  ? ClipRRect(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                      child: Image.network(
                        item.photos.first,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.fastfood,
                          size: 32,
                          color: Colors.grey[400],
                        ),
                      ),
                    )
                  : Icon(
                      Icons.fastfood,
                      size: 32,
                      color: Colors.grey[400],
                    ),
            ),

            // Item details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.price.toStringAsFixed(0)}đ',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Quantity badge
            if (cartItem.quantity > 0)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${cartItem.quantity}',
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.add_circle_outline,
                  color: Colors.grey[400],
                  size: 24,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuInterface() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'pos_page.search_placeholder'.tr(),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),

        // Category filter dropdown
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: DropdownButtonFormField<String?>(
            value: _selectedCategory,
            decoration: InputDecoration(
              labelText: 'pos_page.category_label'.tr(),
              prefixIcon: const Icon(Icons.category),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text('pos_page.all_categories_option'.tr()),
              ),
              ..._availableCategories.map((category) {
                return DropdownMenuItem<String?>(
                  value: category,
                  child: Text(category),
                );
              }),
            ],
            onChanged: (value) {
              setState(() {
                _selectedCategory = value;
              });
            },
          ),
        ),

        // Menu items grouped by category
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredMenuItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isNotEmpty ? Icons.search_off : Icons.restaurant_menu,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Không tìm thấy món ăn phù hợp'
                                : 'Không có món nào',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_searchQuery.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Thử tìm kiếm với từ khóa khác',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : _buildCategorizedItemsList(),
        ),

        // Bottom Cart Button
        if (_cartItems.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: GestureDetector(
                onTap: _showCartBottomSheet,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[600]!, Colors.blue[700]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                            const Icon(
                              Icons.shopping_cart,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'pos_page.cart_header'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Text(
                          '${_totalAmount.toStringAsFixed(0)}đ',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'pos_page.order_section'.tr(),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            // Order information section
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _existingOrderId != null ? Colors.orange[50] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: _existingOrderId != null ? Border.all(color: Colors.orange[200]!, width: 1) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show indicator when editing existing order
                  if (_existingOrderId != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, size: 12, color: Colors.orange[700]),
                          const SizedBox(width: 4),
                          Text(
                            'Editing Order ${_existingOrderNumber ?? ''}',
                            style: TextStyle(fontSize: 10, color: Colors.orange[700], fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  // Order source label removed as per user request
                  // Row(
                  //   children: [
                  //     Icon(Icons.table_restaurant, size: 16, color: Colors.grey[700]),
                  //     const SizedBox(width: 8),
                  //     Text(
                  //       'pos_page.order_source_label'.tr(namedArgs: {'source': _selectedTable}),
                  //       style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                  //     ),
                  //   ],
                  // ),
                  // Show saved customer information (compact display)
                  if (_selectedCustomer != null && _selectedCustomer!.name != 'pos_page.walk_in_customer'.tr()) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue[200]!, width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person, size: 14, color: Colors.blue[700]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              (_selectedCustomer!.phone?.isNotEmpty ?? false)
                                ? '${_selectedCustomer!.name} • ${_selectedCustomer!.phone}'
                                : _selectedCustomer!.name,
                              style: TextStyle(fontSize: 12, color: Colors.blue[800], fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView.builder(
                itemCount: _cartItems.length,
                itemBuilder: (context, index) {
                  final cartItem = _cartItems[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Item header with name and controls
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  cartItem.menuItem.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              Row(
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
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Base price
                          Text(
                            'Base: ${cartItem.menuItem.price.toStringAsFixed(0)}đ',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),

                          // Selected options
                          if (cartItem.selectedOptions.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            ...cartItem.selectedOptions.map((option) => Padding(
                              padding: const EdgeInsets.only(top: 1),
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
                          const SizedBox(height: 2),
                          Text(
                            'Total per item: ${(cartItem.totalPrice / cartItem.quantity).toStringAsFixed(0)}đ',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),

                          const SizedBox(height: 4),

                          // Item notes field
                          TextField(
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'pos_page.item_note_label'.tr(),
                              hintText: 'pos_page.item_note_placeholder'.tr(),
                              prefixIcon: const Icon(Icons.edit_note, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              isDense: true,
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            style: const TextStyle(fontSize: 13),
                            onChanged: (value) {
                              setState(() {
                                cartItem.notes = value;
                              });
                            },
                            controller: TextEditingController(text: cartItem.notes ?? '')
                              ..selection = TextSelection.fromPosition(
                                TextPosition(offset: (cartItem.notes ?? '').length),
                              ),
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
                Text(
                  'pos_page.total_label'.tr(),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${_totalAmount.toStringAsFixed(0)}đ',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Order notes field
            TextField(
              maxLines: 2,
              controller: _orderNotesController,
              decoration: InputDecoration(
                labelText: 'pos_page.order_note_label'.tr(),
                hintText: 'pos_page.order_note_placeholder'.tr(),
                prefixIcon: const Icon(Icons.note_alt_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              onChanged: (value) {
                setState(() {
                  _orderNotes = value;
                });
              },
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                // Save Order button
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saveOrder,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange[700],
                      side: BorderSide(color: Colors.orange[700]!),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      'pos_page.save_order_button'.tr(),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Check Out button
                Expanded(
                  child: ElevatedButton(
                    onPressed: _processPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      'pos_page.checkout_button'.tr(),
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveOrder() async {
    // Enable save order mode (skip validations)
    setState(() {
      _isInSaveOrderMode = true;
    });

    // Close the cart bottom sheet
    Navigator.pop(context);

    // Save order validation: only check if cart has items, allow other fields to be empty
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('pos_page.empty_cart_error'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isInSaveOrderMode = false;
      });
      return;
    }

    try {
      final now = DateTime.now();

      // Convert cart items to order items
      final orderItems = _cartItems.map((cartItem) {
        // Convert SelectedOptions from menu_options to order model
        final orderSelectedOptions = cartItem.selectedOptions.map((opt) {
          return order_model.SelectedOption(
            optionGroupId: opt.optionGroupId,
            optionGroupName: opt.optionGroupName,
            optionId: opt.optionId,
            optionName: opt.optionName,
            price: opt.optionPrice,
          );
        }).toList();

        return order_model.OrderItem(
          id: '',
          menuItemId: cartItem.menuItem.id,
          menuItemName: cartItem.menuItem.name,
          basePrice: cartItem.menuItem.price,
          quantity: cartItem.quantity,
          selectedOptions: orderSelectedOptions,
          subtotal: cartItem.totalPrice,
          notes: (cartItem.notes == null || cartItem.notes!.isEmpty) ? null : cartItem.notes,
        );
      }).toList();

      // Determine order type based on table
      order_model.OrderType orderType;
      if (_selectedTable == 'pos_page.default_table'.tr()) {
        orderType = order_model.OrderType.takeaway;
      } else if (_selectedTable == 'Grab') {
        orderType = order_model.OrderType.delivery;
      } else {
        orderType = order_model.OrderType.dineIn;
      }

      // Convert Customer to order model Customer
      final orderCustomer = _selectedCustomer != null
          ? order_model.Customer(
              id: _selectedCustomer!.id,
              name: _selectedCustomer!.name,
              phone: _selectedCustomer!.phone,
              email: _selectedCustomer!.email,
              address: _selectedCustomer!.address,
              createdAt: _selectedCustomer!.createdAt,
              updatedAt: _selectedCustomer!.updatedAt,
            )
          : order_model.Customer(
              id: '',
              name: 'pos_page.walk_in_customer'.tr(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

      // Check if we're updating an existing order or creating a new one
      String displayOrderNumber;

      if (_existingOrderId != null && _existingOrderNumber != null) {
        // Update existing order - preserve ALL original information
        displayOrderNumber = _existingOrderNumber!;

        // Calculate total considering original discount and fees
        final orderSubtotal = _totalAmount;
        final orderDiscount = _originalDiscount ?? 0.0;
        final orderTax = _originalTax ?? 0.0;
        final orderServiceCharge = _originalServiceCharge ?? 0.0;
        final orderDeliveryFee = _originalDeliveryFee ?? 0.0;
        final orderTotal = orderSubtotal - orderDiscount + orderTax + orderServiceCharge + orderDeliveryFee;

        final order = order_model.Order(
          id: _existingOrderId!,
          orderNumber: _existingOrderNumber!,
          customer: orderCustomer,
          items: orderItems,
          subtotal: orderSubtotal,
          discount: orderDiscount,
          tax: orderTax,
          serviceCharge: orderServiceCharge,
          deliveryFee: orderDeliveryFee,
          total: orderTotal,
          orderType: _originalOrderType ?? orderType, // Preserve original order type
          status: order_model.OrderStatus.pending, // Keep as pending for active orders
          paymentMethod: _originalPaymentMethod ?? order_model.PaymentMethod.cash, // Preserve original payment method
          paymentStatus: _originalPaymentStatus ?? order_model.PaymentStatus.pending, // Preserve original payment status
          tableNumber: _selectedTable,
          platform: _originalPlatform ?? 'POS', // Preserve original platform
          notes: _orderNotes.isEmpty ? null : _orderNotes,
          createdAt: _existingOrderCreatedAt ?? now, // Preserve original creation time
          updatedAt: now,
        );

        await _orderService.updateOrder(order);
      } else {
        // Create new order
        final orderNumber = 'ORD-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour}${now.minute}${now.second}';
        displayOrderNumber = orderNumber;

        final order = order_model.Order(
          id: '',
          orderNumber: orderNumber,
          customer: orderCustomer,
          items: orderItems,
          subtotal: _totalAmount,
          total: _totalAmount,
          orderType: orderType,
          status: order_model.OrderStatus.pending,
          paymentMethod: order_model.PaymentMethod.cash,
          paymentStatus: order_model.PaymentStatus.pending,
          tableNumber: _selectedTable,
          platform: 'POS',
          notes: _orderNotes.isEmpty ? null : _orderNotes,
          createdAt: now,
          updatedAt: now,
        );

        await _orderService.createOrder(order);
      }

      if (mounted) {
        // If we were editing an existing order, navigate back to Orders page
        if (_existingOrderId != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('pos_page.order_updated'.tr(namedArgs: {'orderNumber': displayOrderNumber})),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 1),
            ),
          );

          // Reset save order mode and navigate back
          setState(() {
            _isInSaveOrderMode = false;
          });

          // Wait a moment for the snackbar to show, then navigate back
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.of(context).pop(); // Go back to Orders page
            }
          });
        } else {
          // New order created - show informative notification and clear cart
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'pos_page.order_saved'.tr(namedArgs: {'orderNumber': displayOrderNumber}),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'pos_page.order_added_to_queue'.tr(),
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(
                top: 80,
                left: 10,
                right: 10,
              ),
              action: SnackBarAction(
                label: 'Xem',
                textColor: Colors.white,
                onPressed: () {
                  // Navigate to Orders page
                  context.go('/orders');
                },
              ),
            ),
          );

          // Clear cart for new order
          setState(() {
            _cartItems = [];
            _selectedCustomer = null;
            _selectedTable = 'pos_page.default_table'.tr();
            _orderNotes = '';
            _orderNotesController.text = '';
            _existingOrderId = null;
            _existingOrderNumber = null;
            _existingOrderCreatedAt = null;
            // Reset save order mode
            _isInSaveOrderMode = false;
          });
        }
      }
    } catch (e) {
      // Reset save order mode on error
      setState(() {
        _isInSaveOrderMode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('pos_page.save_error'.tr(namedArgs: {'error': e.toString()})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processPayment() async {
    // Ensure save order mode is disabled (enforce full validation)
    setState(() {
      _isInSaveOrderMode = false;
    });

    // Navigate away from cart bottom sheet first
    Navigator.pop(context);

    if (_cartItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('pos_page.empty_cart_error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Create a temporary order for checkout
    try {
      final now = DateTime.now();
      final orderNumber = 'ORD-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour}${now.minute}${now.second}';

      // Convert cart items to order items
      final orderItems = _cartItems.map((cartItem) {
        final orderSelectedOptions = cartItem.selectedOptions.map((opt) {
          return order_model.SelectedOption(
            optionGroupId: opt.optionGroupId,
            optionGroupName: opt.optionGroupName,
            optionId: opt.optionId,
            optionName: opt.optionName,
            price: opt.optionPrice,
          );
        }).toList();

        return order_model.OrderItem(
          id: '',
          menuItemId: cartItem.menuItem.id,
          menuItemName: cartItem.menuItem.name,
          basePrice: cartItem.menuItem.price,
          quantity: cartItem.quantity,
          selectedOptions: orderSelectedOptions,
          subtotal: cartItem.totalPrice,
          notes: (cartItem.notes == null || cartItem.notes!.isEmpty) ? null : cartItem.notes,
        );
      }).toList();

      // Determine order type
      order_model.OrderType orderType;
      if (_selectedTable == 'pos_page.default_table'.tr()) {
        orderType = order_model.OrderType.takeaway;
      } else if (_selectedTable == 'Grab') {
        orderType = order_model.OrderType.delivery;
      } else {
        orderType = order_model.OrderType.dineIn;
      }

      // Convert Customer
      final orderCustomer = _selectedCustomer != null
          ? order_model.Customer(
              id: _selectedCustomer!.id,
              name: _selectedCustomer!.name,
              phone: _selectedCustomer!.phone,
              email: _selectedCustomer!.email,
              address: _selectedCustomer!.address,
              createdAt: _selectedCustomer!.createdAt,
              updatedAt: _selectedCustomer!.updatedAt,
            )
          : order_model.Customer(
              id: '',
              name: 'pos_page.walk_in_customer'.tr(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

      // Create order in database first
      final order = order_model.Order(
        id: '',
        orderNumber: orderNumber,
        customer: orderCustomer,
        items: orderItems,
        subtotal: _totalAmount,
        total: _totalAmount,
        orderType: orderType,
        status: order_model.OrderStatus.pending,
        paymentMethod: order_model.PaymentMethod.cash,
        paymentStatus: order_model.PaymentStatus.pending,
        tableNumber: _selectedTable,
        platform: 'POS',
        notes: _orderNotes.isEmpty ? null : _orderNotes,
        createdAt: now,
        updatedAt: now,
      );

      // Save order to database and get the generated ID
      final orderId = await _orderService.createOrder(order);

      // Create order with the actual database ID for checkout
      final orderWithId = order.copyWith(id: orderId);

      // Navigate to checkout page
      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CheckoutPage(order: orderWithId),
          ),
        );

        // If checkout was successful, clear cart
        if (result == true && mounted) {
          setState(() {
            _cartItems.clear();
            _selectedCustomer = null;
            _orderNotes = '';
            _orderNotesController.text = '';
            _existingOrderId = null;
            _existingOrderNumber = null;
            _existingOrderCreatedAt = null;
            // Clear preserved order details
            _originalOrderType = null;
            _originalPlatform = null;
            _originalPaymentMethod = null;
            _originalPaymentStatus = null;
            _originalDiscount = null;
            _originalTax = null;
            _originalServiceCharge = null;
            _originalDeliveryFee = null;
            // Reset save order mode
            _isInSaveOrderMode = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('pos_page.generic_error'.tr(namedArgs: {'error': e.toString()})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showOptionSelectionModal(MenuItem menuItem, List<OptionGroup> optionGroups, {bool skipValidation = false}) {
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

          // Validate selections (only if validation is not skipped)
          if (!skipValidation) {
            for (final group in optionGroups) {
              if (group.isRequired) {
                if (group.maxSelection > 1) {
                  final selectedCount = selectedMultipleOptionsMap[group.id]?.length ?? 0;
                  if (selectedCount < group.minSelection) {
                    canAddToCart = false;
                    errorMessage = 'pos_page.min_selection_error'.tr(namedArgs: {'min': group.minSelection.toString(), 'group': group.name});
                    break;
                  }
                } else {
                  if (selectedOptionsMap[group.id] == null) {
                    canAddToCart = false;
                    errorMessage = 'pos_page.required_selection_error'.tr(namedArgs: {'group': group.name});
                    break;
                  }
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
                      if (menuItem.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          menuItem.description,
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
                                          child: Text(
                                            'pos_page.option_required'.tr(),
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
                                        ? 'pos_page.select_range_options'.tr(namedArgs: {'min': group.minSelection.toString(), 'max': group.maxSelection.toString()})
                                        : 'pos_page.select_one_option'.tr(),
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
                      child: Text('pos_page.add_to_cart'.tr()),
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
    return Scaffold(
      body: _buildMenuInterface(),
    );
  }
}