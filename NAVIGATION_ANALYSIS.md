# Navigation Architecture Analysis

## Overview
This Flutter app uses **go_router** for navigation with a standard route-based approach. The navigation system is relatively simple, using direct navigator pushes for order editing rather than route parameters.

---

## 1. Orders Page Navigation

### Route Definition
**File:** `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/core/router/app_router.dart` (Lines 112-115)

```dart
GoRoute(
  path: '/orders',
  builder: (context, state) => const OrdersPage(),
),
```

### Key Points:
- **Simple named route** with no parameters
- **No query parameters** or path parameters are defined
- Basic path routing without state passing

---

## 2. Navigation Methods to Orders Page

### Method 1: Direct Router Navigation
**Pattern:** Using `context.go()`

```dart
// From recent_orders.dart (line 64)
onPressed: () => context.go('/orders'),

// From pos_page.dart
context.go('/orders');
```

**Example Location:** `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/features/dashboard/presentation/widgets/recent_orders.dart` (Lines 64-65)

### Method 2: Router Extension Method
**File:** `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/core/router/app_router.dart` (Lines 169-171)

```dart
// Type-safe extension method
extension AppRoutes on GoRouter {
  void goToOrders() => go('/orders');
}
```

**Usage:**
```dart
context.read(appRouterProvider).goToOrders();
// OR
ref.read(appRouterProvider).goToOrders();
```

---

## 3. Order Parameter Passing Mechanism

### Current Implementation: Material Navigation
**The app does NOT use GoRouter parameters for order passing.** Instead, it uses traditional Flutter `Navigator.push()` with parameters.

**File:** `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/features/orders/presentation/pages/orders_page.dart` (Lines 774-785)

```dart
void _navigateToOrderDetail(Order order) {
  // Navigate to POS page for editing with existing order
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => PosPage(existingOrder: order),
    ),
  ).then((result) {
    // Reload orders when returning from POS
    if (result == true) {
      _loadOrders(showLoading: false);
    }
  });
}
```

### Navigation Flow Diagram:
```
Orders Page
    ↓
    └─→ User clicks "Edit" button on order card
        ↓
        └─→ _navigateToOrderDetail(order) is called
            ↓
            └─→ Navigator.push() with PosPage(existingOrder: order)
                ↓
                └─→ PosPage loads and processes existingOrder parameter
```

---

## 4. Order Detail Page Implementation

### How Orders are Edited
**File:** `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/features/pos/presentation/pages/pos_page.dart` (Lines 41-44)

```dart
class PosPage extends ConsumerStatefulWidget {
  final order_model.Order? existingOrder;

  const PosPage({super.key, this.existingOrder});
```

### Order Loading Process
**File:** `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/features/pos/presentation/pages/pos_page.dart` (Lines 113-117)

```dart
// Load existing order if provided
if (widget.existingOrder != null) {
  _loadExistingOrder(widget.existingOrder!);
  // Show editing indicator and smoothly transition to cart
  _showEditingTransition();
}
```

### Order Data Processing
**File:** `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/features/pos/presentation/pages/pos_page.dart` (Lines 136-207)

The `_loadExistingOrder()` method:
1. Converts order items to cart items
2. Matches order items with menu items by ID
3. Converts selected options to POS selected options
4. Loads customer information
5. Stores order ID, number, and creation time for updates
6. Initializes form controllers with existing data

```dart
void _loadExistingOrder(order_model.Order order) {
  final cartItems = <CartItem>[];

  for (final orderItem in order.items) {
    // Find the menu item from loaded menu items
    final menuItem = _menuItems.firstWhere(
      (item) => item.id == orderItem.menuItemId,
      orElse: () => MenuItem(...)
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
    _selectedCustomer = Customer(...);
    _existingOrderId = order.id;
    _existingOrderNumber = order.orderNumber;
    _existingOrderCreatedAt = order.createdAt;
    _orderNotes = order.notes ?? '';
    _orderNotesController.text = _orderNotes;
    // ... more initialization
  });
}
```

---

## 5. Scrolling & Highlighting Specific Orders

### Current Implementation: No Built-in Scroll/Highlight Feature

The app **does not have a mechanism** to scroll to or highlight a specific order based on parameters.

However, the following infrastructure exists that could be used:

### Scroll Controller Setup
**File:** `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/features/orders/presentation/pages/orders_page.dart` (Lines 30-31)

```dart
// Scroll controllers to preserve scroll position
final ScrollController _activeOrdersScrollController = ScrollController();
final ScrollController _historyOrdersScrollController = ScrollController();
```

### Page Storage Keys
**File:** `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/features/orders/presentation/pages/orders_page.dart` (Lines 233-234, 551)

```dart
// Active orders list
key: const PageStorageKey('active_orders_list'),
controller: _activeOrdersScrollController,

// History orders list
key: const PageStorageKey('history_orders_list'),
controller: _historyOrdersScrollController,
```

These keys preserve scroll position when navigating away and returning.

---

## 6. Route Parameters Overview

### Defined Route Parameters

**Routes WITH parameters:**
- `/menu/option-groups/:id/edit` - Edit option group by ID
- `/menu/items/:id/edit` - Edit menu item by ID

**Routes WITHOUT parameters:**
- `/dashboard`
- `/orders` ❌ **No parameters**
- `/pos` ❌ **No parameters**
- `/analytics`
- `/finance`
- `/settings`
- `/menu`
- `/login`
- `/signup`

**Parameter Extraction Example (from menu routes):**
```dart
GoRoute(
  path: 'option-groups/:id/edit',
  builder: (context, state) {
    final id = state.pathParameters['id']!;
    return OptionGroupEditorPage(optionGroupId: id);
  },
),
```

---

## 7. Navigation Call Sites

### All Navigation to Orders Page

**File 1:** `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/core/router/app_router.dart` (Line 171)
```dart
void goToOrders() => go('/orders');
```

**File 2:** `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/features/dashboard/presentation/widgets/recent_orders.dart` (Line 64)
```dart
TextButton(
  onPressed: () => context.go('/orders'),
  child: const Text('View All'),
),
```

**File 3:** `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/features/pos/presentation/pages/pos_page.dart`
```dart
context.go('/orders');
```

### All Navigation FROM Orders Page

**Navigation to Edit Order (POS Page):**

**Method 1:** Edit button on order card
```dart
ElevatedButton(
  onPressed: () => _navigateToOrderDetail(order),
  child: const Text('Edit', style: TextStyle(fontSize: 12)),
),
```

**Method 2:** Clicking order number
```dart
InkWell(
  onTap: () => _navigateToCheckoutWithOrder(order),
  // ...
)
```

**Both methods call:**
```dart
void _navigateToOrderDetail(Order order) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => PosPage(existingOrder: order),
    ),
  ).then((result) {
    if (result == true) {
      _loadOrders(showLoading: false);
    }
  });
}
```

---

## 8. Order Data Models

### Order Model
**File:** `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/models/order.dart`

Key properties for navigation:
```dart
class Order {
  final String id;              // Unique identifier
  final String orderNumber;     // Display number
  final OrderStatus status;     // pending, confirmed, preparing, ready, delivered, cancelled
  final List<OrderItem> items;  // Order contents
  final Customer customer;      // Customer info
  final String? tableNumber;    // For dine-in
  final String? notes;          // Order notes
  final DateTime createdAt;     // Creation timestamp
  // ... more properties
}
```

---

## 9. ShellRoute Architecture

**File:** `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/core/router/app_router.dart` (Lines 73-133)

The app uses a **ShellRoute** to wrap all main routes with a persistent navigation layout (`MainLayout`):

```dart
ShellRoute(
  builder: (context, state, child) => MainLayout(child: child),
  routes: [
    GoRoute(path: '/dashboard', ...),
    GoRoute(path: '/menu', ...),
    GoRoute(path: '/orders', ...),    // ← Orders route inside shell
    GoRoute(path: '/pos', ...),
    GoRoute(path: '/analytics', ...),
    GoRoute(path: '/finance', ...),
    GoRoute(path: '/settings', ...),
  ],
),
```

This means:
- All main routes preserve the navigation UI (bottom tabs, top bar)
- Returning from nested routes maintains app structure
- Modal navigation (POS page) pops off and returns to orders

---

## 10. Data Refresh Pattern

### Reload on Return
**File:** `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/features/orders/presentation/pages/orders_page.dart` (Lines 780-785)

```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => PosPage(existingOrder: order),
  ),
).then((result) {
  // Reload orders when returning from POS
  if (result == true) {
    _loadOrders(showLoading: false);
  }
});
```

**Pattern:**
1. User edits order in POS page
2. User saves/completes order
3. PosPage pops with `true` result
4. OrdersPage catches result and reloads orders
5. UI updates with new state

---

## 11. Summary of Navigation Patterns

| Pattern | Usage | Location |
|---------|-------|----------|
| **GoRouter Direct** | Navigate to main routes | `context.go('/orders')` |
| **Router Extension** | Type-safe route navigation | `ref.read(appRouterProvider).goToOrders()` |
| **Material Navigator** | Pass complex objects | `Navigator.push(MaterialPageRoute(...))` |
| **Path Parameters** | Dynamic routes (menu items only) | `/menu/items/:id/edit` |
| **Constructor Parameters** | Pass Order objects | `PosPage(existingOrder: order)` |
| **Modal Navigation** | Full-screen edits | `MaterialPageRoute` (replaces ShellRoute) |

---

## 12. Potential Improvements

### Add Order ID to Route Parameters
Current:
```dart
GoRoute(path: '/orders', ...),
```

Proposed:
```dart
GoRoute(
  path: '/orders/:orderId',
  builder: (context, state) {
    final orderId = state.pathParameters['orderId'];
    return OrdersPage(highlightOrderId: orderId);
  },
),
```

### Add Scroll-to-Order Feature
```dart
class OrdersPage extends ConsumerStatefulWidget {
  final String? scrollToOrderId;
  
  void _scrollToOrder(String orderId) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index >= 0) {
      _activeOrdersScrollController.animateTo(
        index * itemHeight,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
}
```

### Add Highlight Animation
Add visual highlight to specific order card for 2-3 seconds after navigation.

---

## Files Referenced

1. `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/core/router/app_router.dart` - Router config
2. `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/features/orders/presentation/pages/orders_page.dart` - Orders page
3. `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/features/pos/presentation/pages/pos_page.dart` - POS page (order editing)
4. `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/features/dashboard/presentation/widgets/recent_orders.dart` - Navigation entry point
5. `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/models/order.dart` - Order data model

