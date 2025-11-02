# Navigation Code Flow - Detailed Examples

## Complete Navigation Flow: Dashboard to Edit Order

### Step 1: Navigate to Orders Page
**Location:** Dashboard Recent Orders Widget
**File:** `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/features/dashboard/presentation/widgets/recent_orders.dart`

```dart
// Line 63-66
TextButton(
  onPressed: () => context.go('/orders'),  // Navigate to orders page
  child: const Text('View All'),
),
```

### Step 2: OrdersPage Loads
**File:** `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/features/orders/presentation/pages/orders_page.dart`

```dart
// Lines 10-15
class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}
```

### Step 3: Load Orders Data
**File:** `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/features/orders/presentation/pages/orders_page.dart` (Lines 34-39)

```dart
@override
void initState() {
  super.initState();
  _tabController = TabController(length: 2, vsync: this);
  WidgetsBinding.instance.addObserver(this);
  _loadOrders();  // Fetch orders from database
  _startRefreshTimer();
}
```

### Step 4: Display Orders in List
**File:** `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/features/orders/presentation/pages/orders_page.dart` (Lines 233-244)

```dart
return RefreshIndicator(
  onRefresh: _loadOrders,
  child: ListView.builder(
    key: const PageStorageKey('active_orders_list'),
    controller: _activeOrdersScrollController,
    padding: const EdgeInsets.all(16),
    itemCount: _activeOrders.length,
    itemBuilder: (context, index) {
      final order = _activeOrders[index];
      return _buildActiveOrderCard(order, index);  // Build each order card
    },
  ),
);
```

### Step 5: Build Order Card with Edit Button
**File:** `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/features/orders/presentation/pages/orders_page.dart` (Lines 246-420)

```dart
Widget _buildActiveOrderCard(Order order, int index) {
  // ... UI code ...
  
  // Edit button
  SizedBox(
    height: 32,
    child: ElevatedButton(
      onPressed: () => _navigateToOrderDetail(order),  // Click handler
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      child: const Text('Edit', style: TextStyle(fontSize: 12)),
    ),
  ),
  // ... more UI ...
}
```

### Step 6: Navigate to POS Page for Editing
**File:** `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/features/orders/presentation/pages/orders_page.dart` (Lines 774-786)

```dart
void _navigateToOrderDetail(Order order) {
  // Navigate to POS page for editing with existing order
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => PosPage(existingOrder: order),  // Pass full order object
    ),
  ).then((result) {
    // Reload orders when returning from POS
    if (result == true) {
      _loadOrders(showLoading: false);
    }
  });
}
```

### Step 7: POS Page Receives Order
**File:** `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/features/pos/presentation/pages/pos_page.dart` (Lines 41-44)

```dart
class PosPage extends ConsumerStatefulWidget {
  final order_model.Order? existingOrder;  // Receive order parameter

  const PosPage({super.key, this.existingOrder});

  @override
  ConsumerState<PosPage> createState() => _PosPageState();
}
```

### Step 8: Load Menu Items
**File:** `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/features/pos/presentation/pages/pos_page.dart` (Lines 96-124)

```dart
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
      _loadExistingOrder(widget.existingOrder!);
      _showEditingTransition();
    }
  } catch (e) {
    setState(() {
      _isLoading = false;
    });
  }
}
```

### Step 9: Load Existing Order Data
**File:** `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/features/pos/presentation/pages/pos_page.dart` (Lines 136-207)

```dart
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
    _originalPaymentMethod = order.paymentMethod;
    _originalPaymentStatus = order.paymentStatus;
    _originalDiscount = order.discount;
    _originalTax = order.tax;
    _originalServiceCharge = order.serviceCharge;
    _originalDeliveryFee = order.deliveryFee;
  });
}
```

### Step 10: Show Cart Sheet
**File:** `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/features/pos/presentation/pages/pos_page.dart` (Lines 210-216)

```dart
void _showEditingTransition() {
  // Open cart immediately after order loads with minimal delay
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _cartItems.isNotEmpty) {
      _showCartBottomSheet();  // Display cart with order items
    }
  });
}
```

### Step 11: User Saves Order Changes
**File:** `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/features/pos/presentation/pages/pos_page.dart`

The user can:
1. Modify quantities
2. Add/remove items
3. Change customer info
4. Apply discount
5. Click "Save Order" button

### Step 12: Return to Orders Page
```dart
// When user clicks save or complete
Navigator.pop(context, true);  // Return true = changes made
```

### Step 13: Orders Page Reloads
**File:** `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/features/orders/presentation/pages/orders_page.dart` (Lines 780-785)

```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => PosPage(existingOrder: order),
  ),
).then((result) {
  // Reload orders when returning from POS
  if (result == true) {
    _loadOrders(showLoading: false);  // Refresh list
  }
});
```

The `_loadOrders()` method fetches fresh data and updates the UI.

---

## Data Model: Order Object Structure

### Order Class Properties Used in Navigation
**File:** `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/models/order.dart`

```dart
class Order {
  final String id;                          // Unique DB ID
  final String orderNumber;                 // Display number
  final OrderStatus status;                 // pending, confirmed, preparing, ready, delivered, cancelled
  final List<OrderItem> items;              // Items in order
  final Customer customer;                  // Customer info
  final String? tableNumber;                // Table for dine-in
  final String? notes;                      // Order notes
  final DateTime createdAt;                 // When created
  final DateTime updatedAt;                 // Last update
  final double subtotal;                    // Total before discount/tax
  final double discount;                    // Discount amount
  final double tax;                         // Tax amount
  final double total;                       // Final total
  final OrderType? orderType;              // delivery, dine_in, takeout
  final String? platform;                  // web, app, phone, etc.
  final PaymentMethod? paymentMethod;      // cash, card, etc.
  final PaymentStatus? paymentStatus;      // pending, paid, refunded
  final double serviceCharge;               // Service fee
  final double deliveryFee;                // Delivery fee
  // ... more properties
}

class OrderItem {
  final String id;
  final String menuItemId;
  final String menuItemName;
  final double basePrice;
  final int quantity;
  final List<OrderItemOption> selectedOptions;
  final String? notes;
  final double subtotal;
}

class OrderItemOption {
  final String optionGroupId;
  final String optionGroupName;
  final String optionId;
  final String optionName;
  final double price;
}

class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

---

## Alternative Navigation: Not Currently Used

### What Could Be Done (If Route Parameters Were Used)

```dart
// Define route with parameter
GoRoute(
  path: '/orders/:orderId',
  builder: (context, state) {
    final orderId = state.pathParameters['orderId'];
    return OrdersPage(highlightOrderId: orderId);
  },
),

// Navigate with parameter
context.go('/orders/order-uuid-here');

// In OrdersPage, scroll to and highlight order
void _scrollToOrder(String orderId) {
  final index = _orders.indexWhere((o) => o.id == orderId);
  if (index >= 0) {
    _activeOrdersScrollController.animateTo(
      index * itemHeight,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    _highlightOrder(orderId);  // Add temporary highlight
  }
}
```

---

## Key Observations

1. **No URL Parameters**: Orders route is simple `/orders` with no ID parameter
2. **Material Navigator Used**: Complex objects passed via constructor, not router state
3. **Full Order Object Passed**: Entire Order object sent, not just ID
4. **Automatic Reload**: Orders page reloads after returning from edit
5. **Scroll Preservation**: PageStorageKey maintains scroll position
6. **No Deep Linking**: Can't navigate directly to order by ID via URL
7. **Modal Navigation**: POS page replaces ShellRoute temporarily
8. **State Management**: Uses Riverpod and local setState

---

## Common Patterns in This Codebase

### Pattern 1: Constructor-Based Navigation
```dart
Navigator.push(
  MaterialPageRoute(
    builder: (context) => PageName(parameter: value),
  ),
)
```

### Pattern 2: Return Value Handling
```dart
.then((result) {
  if (result == true) {
    _loadData();  // Refresh if changes made
  }
})
```

### Pattern 3: Scroll Controller Preservation
```dart
ListView.builder(
  key: const PageStorageKey('unique_key'),
  controller: _scrollController,
  // ... build items ...
)
```

### Pattern 4: Order Loading Pattern
```dart
if (widget.parameter != null) {
  _loadData(widget.parameter);
}
```

