import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../models/menu_item.dart';
import '../../../../models/menu_options.dart';
import '../../../../models/customer.dart';
import '../../../../models/order.dart' as order_model;
import '../../../menu/services/menu_service.dart';
import '../../../../services/menu_option_service.dart';
import '../../../../services/customer_service.dart';
import '../../../../services/order_service.dart';
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
  final order_model.Order? existingOrder;

  const PosPage({super.key, this.existingOrder});

  @override
  ConsumerState<PosPage> createState() => _PosPageState();
}

class _PosPageState extends ConsumerState<PosPage> {
  final MenuService _menuService = MenuService();
  final MenuOptionService _menuOptionService = MenuOptionService();
  final CustomerService _customerService = CustomerService();
  final OrderService _orderService = OrderService();
  List<MenuItem> _menuItems = [];
  Map<String, String> _categories = {};
  List<CartItem> _cartItems = [];
  String _selectedCategory = 'Tất cả';
  String _selectedTable = 'Mang về';
  Customer? _selectedCustomer;
  bool _isLoading = true;

  // Track if we're editing an existing order
  String? _existingOrderId;
  String? _existingOrderNumber;

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
      ));
    }

    setState(() {
      _cartItems = cartItems;
      _selectedTable = order.tableNumber ?? 'Mang về';
      _selectedCustomer = Customer(
        id: order.customer.id,
        name: order.customer.name,
        phone: order.customer.phone ?? '',
        email: order.customer.email ?? '',
        address: order.customer.address ?? '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      // Store the existing order ID and number for updates
      _existingOrderId = order.id;
      _existingOrderNumber = order.orderNumber;
    });
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

  void _showTableSelectionDialog() {
    final tables = ['Mang về', 'Bàn 1', 'Bàn 2', 'Bàn 3', 'Bàn 4', 'Bàn 5', 'Bàn 6', 'Bàn 7', 'Bàn 8', 'Grab'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn bàn'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
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
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: _selectedTable == table ? Colors.blue[50] : Colors.white,
                    border: Border.all(
                      color: _selectedTable == table ? Colors.blue : Colors.grey[300]!,
                      width: _selectedTable == table ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isSpecial ? Icons.delivery_dining : Icons.table_restaurant,
                        size: 24,
                        color: _selectedTable == table ? Colors.blue : Colors.grey[600],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        table,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _selectedTable == table ? Colors.blue : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMenuInterface() {
    return Column(
      children: [
        // Header with table info and customer
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[50],
          child: Row(
            children: [
              // Table selector button
              GestureDetector(
                onTap: _showTableSelectionDialog,
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
              const SizedBox(width: 8),
              // Customer button
              GestureDetector(
                onTap: _showCustomerDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.cyan[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.cyan[800]),
                      const SizedBox(width: 4),
                      Text(
                        _selectedCustomer?.name ?? 'Khách hàng',
                        style: TextStyle(color: Colors.cyan[800], fontWeight: FontWeight.w500),
                      ),
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
                      const Expanded(
                        child: Row(
                          children: [
                            SizedBox(width: 16),
                            Icon(
                              Icons.shopping_cart,
                              color: Colors.white,
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Giỏ hàng',
                              style: TextStyle(
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
            // Order information section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.table_restaurant, size: 16, color: Colors.grey[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Nguồn đơn: $_selectedTable',
                        style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                      ),
                    ],
                  ),
                  if (_selectedCustomer != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.person, size: 16, color: Colors.grey[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Khách hàng: ${_selectedCustomer!.name}',
                                style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                              ),
                              if (_selectedCustomer!.phone != null && _selectedCustomer!.phone!.isNotEmpty)
                                Text(
                                  'SĐT: ${_selectedCustomer!.phone}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
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
            Row(
              children: [
                // Save Order button
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'Lưu đơn',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
                    child: const Text(
                      'Thanh toán',
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
    // Close the cart bottom sheet
    Navigator.pop(context);

    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Giỏ hàng trống'),
          backgroundColor: Colors.red,
        ),
      );
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
        );
      }).toList();

      // Determine order type based on table
      order_model.OrderType orderType;
      if (_selectedTable == 'Mang về') {
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
            )
          : order_model.Customer(
              id: '',
              name: 'Walk-in Customer',
            );

      // Check if we're updating an existing order or creating a new one
      String displayOrderNumber;

      if (_existingOrderId != null && _existingOrderNumber != null) {
        // Update existing order
        displayOrderNumber = _existingOrderNumber!;

        final order = order_model.Order(
          id: _existingOrderId!,
          orderNumber: _existingOrderNumber!,
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
          createdAt: now, // Keep original creation time would be better, but we don't have it
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
              content: Text('Đơn hàng #$displayOrderNumber đã được cập nhật'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 1),
            ),
          );

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
                          'Đơn hàng #$displayOrderNumber đã được lưu',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Đơn hàng đã được thêm vào danh sách Đơn đang xử lý',
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
            _selectedTable = 'Mang về';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lưu đơn hàng: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  Future<void> _completePayment(String method) async {
    if (_cartItems.isEmpty) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Giỏ hàng trống'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Generate order number
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
        );
      }).toList();

      // Determine order type
      order_model.OrderType orderType;
      if (_selectedTable == 'Mang về') {
        orderType = order_model.OrderType.takeaway;
      } else if (_selectedTable == 'Grab') {
        orderType = order_model.OrderType.delivery;
      } else {
        orderType = order_model.OrderType.dineIn;
      }

      // Determine payment method
      order_model.PaymentMethod paymentMethod;
      if (method == 'Tiền mặt') {
        paymentMethod = order_model.PaymentMethod.cash;
      } else if (method == 'Thẻ') {
        paymentMethod = order_model.PaymentMethod.card;
      } else {
        paymentMethod = order_model.PaymentMethod.bankTransfer;
      }

      // Convert Customer
      final orderCustomer = _selectedCustomer != null
          ? order_model.Customer(
              id: _selectedCustomer!.id,
              name: _selectedCustomer!.name,
              phone: _selectedCustomer!.phone,
              email: _selectedCustomer!.email,
              address: _selectedCustomer!.address,
            )
          : order_model.Customer(
              id: '',
              name: 'Walk-in Customer',
            );

      // Create order with paid status
      final order = order_model.Order(
        id: '',
        orderNumber: orderNumber,
        customer: orderCustomer,
        items: orderItems,
        subtotal: _totalAmount,
        total: _totalAmount,
        orderType: orderType,
        status: order_model.OrderStatus.delivered, // Mark as delivered for completed payment
        paymentMethod: paymentMethod,
        paymentStatus: order_model.PaymentStatus.paid,
        tableNumber: _selectedTable,
        platform: 'POS',
        createdAt: now,
        updatedAt: now,
      );

      // Save to database
      await _orderService.createOrder(order);

      // Clear cart
      setState(() {
        _cartItems.clear();
        _selectedCustomer = null;
      });

      // Close dialog
      if (mounted) {
        try {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        } catch (e) {
          debugPrint('Navigation error: $e');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đơn hàng #$orderNumber - Thanh toán thành công bằng $method'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi thanh toán: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  void _showCustomerDialog() {
    // Pre-populate with selected customer if exists
    final phoneController = TextEditingController(text: _selectedCustomer?.phone ?? '');
    final nameController = TextEditingController(text: _selectedCustomer?.name ?? '');
    Customer? foundCustomer = _selectedCustomer;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Thông tin khách hàng'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Phone input
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại',
                      hintText: 'Nhập số điện thoại',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                    onChanged: (value) async {
                      if (value.length >= 9) {
                        // Search for existing customer
                        final customer = await _customerService.getCustomerByPhone(value);
                        setState(() {
                          foundCustomer = customer;
                          if (customer != null) {
                            nameController.text = customer.name;
                          } else {
                            nameController.text = '';
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Show message if customer found
                  if (foundCustomer != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Khách hàng đã tồn tại - Có thể chỉnh sửa tên',
                              style: TextStyle(color: Colors.green[700]),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (foundCustomer != null) const SizedBox(height: 16),

                  // Name input - now always enabled to allow editing
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên khách hàng (tùy chọn)',
                      hintText: 'Nhập tên',
                      border: OutlineInputBorder(),
                      helperText: 'Có thể chỉnh sửa tên cho khách hàng hiện có',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final phone = phoneController.text.trim();
                  final name = nameController.text.trim();

                  if (phone.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vui lòng nhập số điện thoại'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Customer customer;
                  if (foundCustomer != null) {
                    // Check if name was changed
                    final nameChanged = name.isNotEmpty && name != foundCustomer!.name;

                    if (nameChanged) {
                      // Update existing customer with new name
                      final updatedCustomer = foundCustomer!.copyWith(
                        name: name,
                        updatedAt: DateTime.now(),
                      );

                      final success = await _customerService.updateCustomer(updatedCustomer);
                      if (!success) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Không thể cập nhật thông tin khách hàng'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                        return;
                      }
                      customer = updatedCustomer;
                    } else {
                      // Use existing customer without changes
                      customer = foundCustomer!;
                    }
                  } else {
                    // Create new customer
                    final newCustomer = Customer(
                      id: '',
                      name: name.isNotEmpty ? name : 'Khách',
                      phone: phone,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );

                    final customerId = await _customerService.createCustomer(newCustomer);
                    if (customerId == null) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Không thể tạo khách hàng'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }
                    customer = newCustomer.copyWith(id: customerId);
                  }

                  this.setState(() {
                    _selectedCustomer = customer;
                  });

                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                child: const Text('Xác nhận'),
              ),
            ],
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