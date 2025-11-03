import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../models/menu_item.dart';
import '../../../../models/menu_options.dart';
import '../../../../models/customer.dart';
import '../../../../models/order.dart' as order_model;
import '../../../../models/payment_method.dart';
import '../../../../services/transaction_service.dart';
import '../../../../services/order_payment_helper.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../../core/widgets/main_layout.dart' show activeOrdersCountProvider;
import '../../../../core/utils/error_messages.dart';

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
  final TextEditingController _searchController = TextEditingController();
  List<MenuItem> _menuItems = [];
  List<CartItem> _cartItems = [];
  String _searchQuery = '';
  String? _selectedCategory; // null means "All"
  String? _selectedTable;
  Customer? _selectedCustomer;
  bool _isLoading = true;
  String _orderNotes = ''; // Order notes/comments

  // Text controllers for persistent form fields
  late TextEditingController _orderNotesController;
  late TextEditingController _customerNameController;
  late TextEditingController _customerPhoneController;

  // UI state
  double _discountAmount = 0.0;
  bool _isDiscountPercentage = false;
  order_model.PaymentMethod _selectedPaymentMethod = order_model.PaymentMethod.none;
  bool _isPaymentEnabled = false;

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
    _customerNameController = TextEditingController();
    _customerPhoneController = TextEditingController();

    // Load existing order data if editing an order
    if (widget.existingOrder != null) {
      _loadExistingOrderData();
    }

    _loadMenuData();
  }

  void _loadExistingOrderData() {
    final order = widget.existingOrder!;

    setState(() {
      // Load basic order info
      _existingOrderId = order.id;
      _existingOrderNumber = order.orderNumber;
      _existingOrderCreatedAt = order.createdAt;

      // Load payment method from order_payments table
      _loadPaymentMethodForOrder(order.id);

      // Load order notes
      _orderNotes = order.notes ?? '';
      _orderNotesController.text = _orderNotes;

      // Load customer information
      if (order.customer.name.isNotEmpty) {
        _customerNameController.text = order.customer.name;
      }
      if (order.customer.phone != null) {
        _customerPhoneController.text = order.customer.phone!;
      }

      // Convert order.Customer to customer.Customer
      _selectedCustomer = Customer(
        id: order.customer.id,
        name: order.customer.name,
        phone: order.customer.phone,
        email: order.customer.email,
        address: order.customer.address,
        createdAt: order.customer.createdAt ?? DateTime.now(),
        updatedAt: order.customer.updatedAt ?? DateTime.now(),
      );

      // Load table information
      _selectedTable = order.tableNumber;

      // Load discount information
      _discountAmount = order.discount;
      // Note: We don't know if discount was percentage or fixed from the order data
      // This could be enhanced by storing discount type in the order model

      // Load order items into cart
      _cartItems = order.items.map((orderItem) {
        // Convert order item selected options back to menu options format
        final selectedOptions = orderItem.selectedOptions.map((selectedOpt) {
          return SelectedOption(
            optionGroupId: selectedOpt.optionGroupId,
            optionGroupName: selectedOpt.optionGroupName,
            optionId: selectedOpt.optionId,
            optionName: selectedOpt.optionName,
            optionPrice: selectedOpt.price,
          );
        }).toList();

        // Create a simplified MenuItem from the order item data
        final menuItem = MenuItem(
          id: orderItem.menuItemId,
          name: orderItem.menuItemName,
          price: orderItem.basePrice,
          categoryName: '', // Default category name
          description: '',
          photos: const [],
          availableStatus: true,
          sizes: const [],
          recipes: const [],
          displayOrder: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        return CartItem(
          menuItem: menuItem,
          quantity: orderItem.quantity,
          selectedOptions: selectedOptions,
          notes: orderItem.notes,
        );
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _orderNotesController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadMenuData() async {
    try {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final menuService = ref.read(supabaseMenuServiceProvider);
      final menuItems = await menuService.getMenuItems();

      setState(() {
        _menuItems = menuItems;
        _isLoading = false;
      });

      // Load existing order if provided
      if (widget.existingOrder != null) {
        await _loadExistingOrder(widget.existingOrder!);
        // Show editing indicator and smoothly transition to cart
        await _showEditingTransition();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Error loading menu data - handle silently for production
    }
  }

  // Store additional order details to preserve when saving
  order_model.OrderType? _originalOrderType;
  String? _originalPlatform;
  order_model.PaymentStatus? _originalPaymentStatus;
  double? _originalDiscount;
  double? _originalTax;
  double? _originalServiceCharge;
  double? _originalDeliveryFee;

  Future<void> _loadExistingOrder(order_model.Order order) async {
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
      _selectedTable = order.tableNumber;
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

      // Load customer information into controllers
      _customerNameController.text = order.customer.name;
      _customerPhoneController.text = order.customer.phone ?? '';


      // Preserve original order details for saving
      _originalOrderType = order.orderType;
      _originalPlatform = order.platform;
      _originalPaymentStatus = order.paymentStatus;
      _originalDiscount = order.discount;
      _originalTax = order.tax;
      _originalServiceCharge = order.serviceCharge;
      _originalDeliveryFee = order.deliveryFee;
    });

    // Load payment method and status after setting up the order
    await _loadPaymentMethodForOrder(order.id);
  }

  // Load payment method from order_payments table
  Future<void> _loadPaymentMethodForOrder(String orderId) async {
    try {
      print('🔍 DEBUG POS - Looking for payments for order: $orderId');
      final primaryPaymentMethod = await OrderPaymentHelper.getPrimaryPaymentMethod(orderId);
      final hasPayments = await OrderPaymentHelper.hasPayments(orderId);
      print('🔍 DEBUG POS - Primary payment method found: $primaryPaymentMethod');
      print('🔍 DEBUG POS - Has successful payments: $hasPayments');

      setState(() {
        // Set payment enabled status based on whether there are successful payments
        _isPaymentEnabled = hasPayments;
        print('🔍 DEBUG POS - Setting _isPaymentEnabled = $hasPayments');

        if (primaryPaymentMethod != null) {
          // Convert PaymentMethodType to legacy PaymentMethod for UI compatibility
          switch (primaryPaymentMethod) {
            case PaymentMethodType.cash:
              _selectedPaymentMethod = order_model.PaymentMethod.cash;
              break;
            case PaymentMethodType.card:
              _selectedPaymentMethod = order_model.PaymentMethod.card;
              break;
            case PaymentMethodType.mobilePayment:
              _selectedPaymentMethod = order_model.PaymentMethod.mobilePayment;
              break;
            case PaymentMethodType.bankTransfer:
              _selectedPaymentMethod = order_model.PaymentMethod.bankTransfer;
              break;
            case PaymentMethodType.other:
              _selectedPaymentMethod = order_model.PaymentMethod.other;
              break;
          }
          print('🔍 DEBUG POS - Payment method set to: $_selectedPaymentMethod');
        } else if (!hasPayments) {
          // No payments found, reset to none so auto-selection can work
          _selectedPaymentMethod = order_model.PaymentMethod.none;
          print('🔍 DEBUG POS - No payment method found, setting to none');
        }
      });
    } catch (e) {
      print('🔍 DEBUG POS - Error loading payment method: $e');
    }
  }

  Future<void> _showEditingTransition() async {
    // Wait for payment loading to complete, then open cart
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && _cartItems.isNotEmpty) {
        // Add small delay to ensure payment status is fully loaded
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          print('🔍 DEBUG Transition - Opening cart with _isPaymentEnabled: $_isPaymentEnabled');
          _showCartBottomSheet();
        }
      }
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


  Future<void> _addToCart(MenuItem item) async {
    // Check if this menu item has linked option groups
    final menuOptionService = ref.read(supabaseMenuOptionServiceProvider);
    final optionGroups = await menuOptionService.getOptionGroupsForMenuItem(item.id);

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

    return CustomScrollView(
      slivers: [

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
        // Editing indicator banner
        if (_existingOrderId != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              border: Border(
                bottom: BorderSide(color: Colors.orange[200]!, width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.edit, size: 16, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Text(
                  'Editing Order ${_existingOrderNumber ?? ''}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[800],
                  ),
                ),
              ],
            ),
          ),

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
      builder: (context) => StatefulBuilder(
        builder: (context, modalSetState) {
          print('🔍 DEBUG Modal - Opening cart with _isPaymentEnabled: $_isPaymentEnabled');
          return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  Text(
                    'pos_page.order_section'.tr(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              // Order information section
              if (_existingOrderId != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, size: 16, color: Colors.orange[700]),
                      const SizedBox(width: 6),
                      Text(
                        'Editing Order ${_existingOrderNumber ?? ''}',
                        style: TextStyle(fontSize: 12, color: Colors.orange[700], fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

              // Scrollable middle content area
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. ORDERED DISHES SECTION
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Text(
                          'Ordered Dishes',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                        ),
                      ),

                      // Dishes list
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _cartItems.length,
                        itemBuilder: (context, index) {
                          final cartItem = _cartItems[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
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
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _removeFromCart(index);
                                              });
                                              Navigator.pop(context);
                                              if (_cartItems.isNotEmpty) {
                                                _showCartBottomSheet();
                                              }
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.red[50],
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Icon(Icons.remove, size: 16, color: Colors.red[600]),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            child: Text(
                                              '${cartItem.quantity}',
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                cartItem.quantity++;
                                              });
                                              Navigator.pop(context);
                                              _showCartBottomSheet();
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.green[50],
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Icon(Icons.add, size: 16, color: Colors.green[600]),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  // Price and options
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${cartItem.menuItem.price.toStringAsFixed(0)}đ per item',
                                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                            ),
                                            if (cartItem.selectedOptions.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              ...cartItem.selectedOptions.map((option) => Text(
                                                '+ ${option.optionName}${option.optionPrice > 0 ? ' (+${option.optionPrice.toStringAsFixed(0)}đ)' : ''}',
                                                style: TextStyle(
                                                  color: Colors.orange[600],
                                                  fontSize: 10,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              )),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${cartItem.totalPrice.toStringAsFixed(0)}đ',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Individual item note
                                  if (cartItem.notes != null && cartItem.notes!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.yellow[50],
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.yellow[200]!),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.note, size: 12, color: Colors.orange[600]),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              cartItem.notes!,
                                              style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      // Add More Items button
                      Container(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context); // Close the cart modal
                            // The POS screen is already the current screen, so we're already there
                          },
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text('Add More Items'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[100],
                            foregroundColor: Colors.grey[700],
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 2. ORDER NOTE SECTION (Compact)
                      _buildCompactNoteSection(),

                      const SizedBox(height: 8),

                      // 3. CUSTOMER INFORMATION SECTION (Compact)
                      _buildCompactCustomerSection(),

                      const SizedBox(height: 8),

                      // 4. PAYMENT METHOD SELECTION (Compact)
                      _buildCompactPaymentMethodSection(modalSetState),

                      const SizedBox(height: 8),

                      // 5. DISCOUNT SECTION (With percentage option)
                      _buildCompactDiscountSection(modalSetState),

                      const SizedBox(height: 20), // Extra bottom padding for scroll
                    ],
                  ),
                ),
              ),

              // Sticky bottom section with total and actions
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),

                    // 5. TOTAL SECTION (Now sticky)
                    _buildTotalSection(),

                    const SizedBox(height: 16),

                    // 6. ACTION BUTTONS (Now sticky)
                    _buildActionButtons(),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        );
        },
      ),
    );
  }

  // Helper methods for the new POS flow structure

  Widget _buildCompactNoteSection() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextField(
        controller: _orderNotesController,
        maxLines: 2,
        decoration: InputDecoration(
          labelText: 'Order Note',
          hintText: 'Add special instructions...',
          prefixIcon: Icon(Icons.note_alt_outlined, size: 18, color: Colors.orange[600]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 13),
        onChanged: (value) {
          setState(() {
            _orderNotes = value;
          });
        },
      ),
    );
  }

  Widget _buildCompactCustomerSection() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, size: 18, color: Colors.blue[600]),
              const SizedBox(width: 8),
              Text(
                'Customer Info (Optional)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customerNameController,
                  decoration: InputDecoration(
                    hintText: 'Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _customerPhoneController,
                  decoration: InputDecoration(
                    hintText: 'Phone',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 12),
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDiscountSection(StateSetter modalSetState) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.percent, color: Colors.green[600], size: 18),
              const SizedBox(width: 8),
              Text(
                'Discount',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700]),
              ),
              const Spacer(),
              // Toggle between amount and percentage
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        modalSetState(() {
                          _isDiscountPercentage = false;
                          _discountAmount = 0.0;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: !_isDiscountPercentage ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'đ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: !_isDiscountPercentage ? FontWeight.bold : FontWeight.normal,
                            color: !_isDiscountPercentage ? Colors.green[600] : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        modalSetState(() {
                          _isDiscountPercentage = true;
                          _discountAmount = 0.0;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isDiscountPercentage ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _isDiscountPercentage ? FontWeight.bold : FontWeight.normal,
                            color: _isDiscountPercentage ? Colors.green[600] : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              hintText: _isDiscountPercentage ? '0' : '0',
              suffix: Text(
                _isDiscountPercentage ? '%' : 'đ',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              modalSetState(() {
                _discountAmount = double.tryParse(value) ?? 0.0;
              });
            },
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactPaymentMethodSection(StateSetter modalSetState) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.payment, color: Colors.green[600], size: 18),
              const SizedBox(width: 8),
              Text(
                'Payment Method',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700]),
              ),
              const Spacer(),
              // Toggle for enabling payment
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Mark as Paid',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 4),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _isPaymentEnabled,
                      onChanged: (value) {
                        print('🔍 DEBUG Modal - Toggle changed from $_isPaymentEnabled to $value');
                        modalSetState(() {
                          _isPaymentEnabled = value;
                        });
                      },
                      activeTrackColor: Colors.green[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Payment method selection (only show when payment is enabled)
          if (_isPaymentEnabled)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: order_model.PaymentMethod.values
                  .where((method) => method != order_model.PaymentMethod.none)
                  .map((method) {
                final isSelected = _selectedPaymentMethod == method;
                return InkWell(
                  onTap: () {
                    modalSetState(() {
                      _selectedPaymentMethod = method;
                    });
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSelected
                            ? Colors.green[600]!
                            : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      color: isSelected
                          ? Colors.green[600]!.withValues(alpha: 0.1)
                          : Colors.white,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          method.icon,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          method.displayName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected
                                ? Colors.green[600]
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          // Show hint when payment is enabled but no method selected
          if (_isPaymentEnabled && _selectedPaymentMethod == order_model.PaymentMethod.none)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Please select a payment method',
                style: TextStyle(
                  color: Colors.red[600],
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTotalSection() {
    final subtotal = _totalAmount;

    // Calculate discount amount based on type
    final discountAmountCalculated = _isDiscountPercentage
        ? (subtotal * _discountAmount / 100)
        : _discountAmount;

    final finalTotal = subtotal - discountAmountCalculated;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          if (_discountAmount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                Text(
                  '${subtotal.toStringAsFixed(0)}đ',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Discount ${_isDiscountPercentage ? '(${_discountAmount.toStringAsFixed(0)}%)' : ''}',
                  style: TextStyle(fontSize: 14, color: Colors.green[600]),
                ),
                Text(
                  '-${discountAmountCalculated.toStringAsFixed(0)}đ',
                  style: TextStyle(fontSize: 14, color: Colors.green[600]),
                ),
              ],
            ),
            const Divider(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
              ),
              Text(
                '${finalTotal.toStringAsFixed(0)}đ',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _saveOrder,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.orange[700],
          side: BorderSide(color: Colors.orange[700]!),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text(
          'Save Order',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _saveOrder() async {
    // Save order validation: only check if cart has items, allow other fields to be empty
    if (_cartItems.isEmpty) {
      ErrorMessages.showErrorSnackbar(
        context,
        'Empty cart',
        customMessage: ErrorMessages.emptyCartError,
      );
      return;
    }

    // Validate payment method selection when payment is enabled
    if (_isPaymentEnabled && _selectedPaymentMethod == order_model.PaymentMethod.none) {
      ErrorMessages.showErrorSnackbar(
        context,
        'Payment method required',
        customMessage: 'Please select a payment method when marking order as paid',
      );
      return;
    }

    // Always save the selected payment method, but only mark as paid if payment is enabled
    final selectedPaymentMethod = _selectedPaymentMethod;
    final paidAmount = _isPaymentEnabled ? _totalAmount - (_isDiscountPercentage ? (_totalAmount * _discountAmount / 100) : _discountAmount) : null;

    // Directly call the save order method with the selected payment info
    await _performSaveOrder(
      selectedPaymentMethod: selectedPaymentMethod,
      paidAmount: paidAmount,
    );
  }


  Future<void> _performSaveOrder({
    order_model.PaymentMethod? selectedPaymentMethod,
    double? paidAmount,
  }) async {
    final orderService = ref.read(supabaseOrderServiceProvider);

    // Enable save order mode (skip validations)
    setState(() {
      _isInSaveOrderMode = true;
    });

    // Close the cart bottom sheet if it's still open
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
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
      if (_selectedTable == null) {
        // No table selected - use takeaway as fallback but don't pre-select it in UI
        orderType = order_model.OrderType.takeaway;
      } else if (_selectedTable == 'pos_page.default_table'.tr()) {
        orderType = order_model.OrderType.takeaway;
      } else if (_selectedTable == 'Grab') {
        orderType = order_model.OrderType.delivery;
      } else {
        orderType = order_model.OrderType.dineIn;
      }

      // Convert Customer to order model Customer using the new controller values
      final orderCustomer = order_model.Customer(
        id: _selectedCustomer?.id ?? '',
        name: _customerNameController.text.trim(),
        phone: _customerPhoneController.text.trim().isEmpty ? null : _customerPhoneController.text.trim(),
        email: _selectedCustomer?.email,
        address: _selectedCustomer?.address,
        createdAt: _selectedCustomer?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Check if we're updating an existing order or creating a new one
      String displayOrderNumber;

      if (_existingOrderId != null && _existingOrderNumber != null) {
        // Update existing order - preserve ALL original information
        displayOrderNumber = _existingOrderNumber!;

        // Calculate total considering current discount and original fees
        final orderSubtotal = _totalAmount;
        final orderDiscount = _isDiscountPercentage
            ? (orderSubtotal * _discountAmount / 100)
            : _discountAmount;
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
          paymentStatus: (paidAmount != null && paidAmount > 0)
              ? order_model.PaymentStatus.paid
              : _originalPaymentStatus ?? order_model.PaymentStatus.pending,
          tableNumber: _selectedTable,
          platform: _originalPlatform ?? 'POS', // Preserve original platform
          notes: _orderNotesController.text.trim().isEmpty ? null : _orderNotesController.text.trim(),
          createdAt: _existingOrderCreatedAt ?? now, // Preserve original creation time
          updatedAt: now,
        );

        await orderService.updateOrder(order);

        // Handle payment record creation/updating based on payment toggle
        print('🔍 DEBUG Payment - paidAmount: $paidAmount, selectedPaymentMethod: $selectedPaymentMethod, isPaymentEnabled: $_isPaymentEnabled');
        if (paidAmount != null && paidAmount > 0 && selectedPaymentMethod != null) {
          print('🔍 DEBUG Payment - Creating payment record for existing order');
          await _createPaymentRecord(_existingOrderId!, selectedPaymentMethod, paidAmount, order.total);
        } else if (!_isPaymentEnabled) {
          print('🔍 DEBUG Payment - Payment toggle is OFF, marking payments as pending');
          await _handlePaymentToggleOff(_existingOrderId!);
        } else {
          print('🔍 DEBUG Payment - No payment record created for existing order (conditions not met)');
        }
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
          discount: _isDiscountPercentage ? (_totalAmount * _discountAmount / 100) : _discountAmount,
          total: _totalAmount - (_isDiscountPercentage ? (_totalAmount * _discountAmount / 100) : _discountAmount),
          orderType: orderType,
          status: order_model.OrderStatus.pending,
          paymentStatus: (paidAmount != null && paidAmount > 0)
              ? order_model.PaymentStatus.paid
              : order_model.PaymentStatus.pending,
          tableNumber: _selectedTable,
          platform: 'POS',
          notes: _orderNotes.isEmpty ? null : _orderNotes,
          createdAt: now,
          updatedAt: now,
        );

        final createdOrderId = await orderService.createOrder(order);

        // Create payment record if payment was made
        print('🔍 DEBUG Payment - paidAmount: $paidAmount, selectedPaymentMethod: $selectedPaymentMethod');
        if (paidAmount != null && paidAmount > 0 && selectedPaymentMethod != null) {
          print('🔍 DEBUG Payment - Creating payment record for new order');
          await _createPaymentRecord(createdOrderId, selectedPaymentMethod, paidAmount, order.total);
        } else {
          print('🔍 DEBUG Payment - No payment record created for new order (conditions not met)');
        }

        // 🚀 INSTANT BADGE UPDATE: Increment active order count immediately
        ref.read(activeOrdersCountProvider.notifier).incrementCount();
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
              // Close the POS editing modal and return to orders page with target order
              Navigator.of(context).pop(displayOrderNumber);
            }
          });
        } else {
          // New order created - show brief notification and auto-navigate to orders
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'pos_page.order_saved'.tr(namedArgs: {'orderNumber': displayOrderNumber}),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(
                top: 80,
                left: 10,
                right: 10,
              ),
            ),
          );

          // Clear cart for new order
          setState(() {
            _cartItems = [];
            _selectedCustomer = null;
            _selectedTable = null;
            _orderNotes = '';
            _orderNotesController.text = '';
            _customerNameController.text = '';
            _customerPhoneController.text = '';
            _discountAmount = 0.0;
            _isDiscountPercentage = false;
            _existingOrderId = null;
            _existingOrderNumber = null;
            _existingOrderCreatedAt = null;
            // Reset save order mode
            _isInSaveOrderMode = false;
          });

          // Auto-navigate to orders page with target order after brief delay
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              context.go('/orders?orderNumber=${Uri.encodeComponent(displayOrderNumber)}');
            }
          });
        }
      }
    } catch (e) {
      // Reset save order mode on error
      setState(() {
        _isInSaveOrderMode = false;
      });

      if (mounted) {
        ErrorMessages.showErrorSnackbar(
          context,
          e,
          customMessage: ErrorMessages.savingOrderError,
        );
      }
    }
  }

  Future<void> _createPaymentRecord(String orderId, order_model.PaymentMethod paymentMethod, double amount, double totalAmount) async {
    try {
      print('🔍 DEBUG Payment Record - Processing payment: orderId=$orderId, method=$paymentMethod, amount=$amount');
      final transactionService = TransactionService();

      // Convert order model PaymentMethod to payment model PaymentMethodType
      PaymentMethodType paymentMethodType;
      switch (paymentMethod) {
        case order_model.PaymentMethod.cash:
          paymentMethodType = PaymentMethodType.cash;
          break;
        case order_model.PaymentMethod.card:
          paymentMethodType = PaymentMethodType.card;
          break;
        case order_model.PaymentMethod.mobilePayment:
          paymentMethodType = PaymentMethodType.mobilePayment;
          break;
        case order_model.PaymentMethod.bankTransfer:
          paymentMethodType = PaymentMethodType.bankTransfer;
          break;
        default:
          paymentMethodType = PaymentMethodType.cash;
      }

      // Check if we're editing an existing order and have existing payments
      if (_existingOrderId != null) {
        final existingPayments = await transactionService.getPaymentsForOrder(orderId);
        print('🔍 DEBUG Payment Record - Found ${existingPayments.length} existing payments');

        if (existingPayments.isNotEmpty) {
          // Update the most recent payment instead of creating a new one
          final mostRecentPayment = existingPayments.first; // getPaymentsForOrder returns in descending order by created_at
          print('🔍 DEBUG Payment Record - Updating existing payment: ${mostRecentPayment.id}');

          await transactionService.updateTransaction(
            mostRecentPayment.id,
            paymentMethod: paymentMethodType,
            paymentStatus: order_model.PaymentStatus.paid,
            amount: amount,
            notes: 'Payment updated via POS',
            transactionTime: DateTime.now(),
          );
        } else {
          // No existing payments, create new one
          print('🔍 DEBUG Payment Record - Creating new payment for existing order');
          await transactionService.createOrderPayment(
            orderId: orderId,
            paymentMethod: paymentMethodType,
            amountPaid: amount,
            totalAmount: totalAmount,
            paymentStatus: order_model.PaymentStatus.paid,
            notes: 'Payment made via POS',
          );
        }
      } else {
        // New order, create new payment record
        print('🔍 DEBUG Payment Record - Creating new payment for new order');
        await transactionService.createOrderPayment(
          orderId: orderId,
          paymentMethod: paymentMethodType,
          amountPaid: amount,
          totalAmount: totalAmount,
          paymentStatus: order_model.PaymentStatus.paid,
          notes: 'Payment made via POS',
        );
      }

      // Update order payment status to reflect the payment changes
      await transactionService.updateOrderPaymentStatus(orderId);

      // Refresh UI state to reflect the payment changes
      if (mounted) {
        setState(() {
          _isPaymentEnabled = true; // Payment was just processed successfully
        });
        print('🔍 DEBUG Payment Record - UI state updated: _isPaymentEnabled = true');
      }
    } catch (e) {
      // Log error but don't break the order saving flow
      debugPrint('Error processing payment record: $e');
    }
  }

  /// Handle when payment toggle is turned OFF - mark existing payments as pending
  Future<void> _handlePaymentToggleOff(String orderId) async {
    try {
      print('🔍 DEBUG Payment Toggle OFF - Processing order: $orderId');
      final transactionService = TransactionService();
      final existingPayments = await transactionService.getPaymentsForOrder(orderId);

      // Update all existing paid payments to pending status
      for (final payment in existingPayments) {
        if (payment.paymentStatus == order_model.PaymentStatus.paid) {
          print('🔍 DEBUG Payment Toggle OFF - Updating payment ${payment.id} to pending');
          await transactionService.updateTransaction(
            payment.id,
            paymentStatus: order_model.PaymentStatus.pending,
            notes: 'Payment status changed to pending via POS',
          );
        }
      }

      // Update order payment status
      await transactionService.updateOrderPaymentStatus(orderId);

      // Update UI state
      if (mounted) {
        setState(() {
          _isPaymentEnabled = false;
        });
        print('🔍 DEBUG Payment Toggle OFF - UI state updated: _isPaymentEnabled = false');
      }
    } catch (e) {
      debugPrint('Error handling payment toggle off: $e');
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
                                            style: const TextStyle(
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
                            }),
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