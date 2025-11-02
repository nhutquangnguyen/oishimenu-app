# Navigation Quick Reference Guide

## Key Findings Summary

### 1. How Navigation to Orders Works

```
ENTRY POINTS:
├─ Dashboard → "View All" button → context.go('/orders')
├─ Recent Orders → "View All" button → context.go('/orders')
└─ POS Page → Save/Cancel → context.go('/orders')

ROUTE PATH:
└─ /orders (no parameters)

ROUTE DEFINITION:
└─ Simple GoRoute with no parameters
```

### 2. How Order IDs/Numbers Are Passed

```
CURRENT METHOD: Material Navigator (NOT GoRouter)

Orders Page                           POS Page
    ↓
User clicks "Edit"
    ↓
_navigateToOrderDetail(order)
    ↓
Navigator.push(
  MaterialPageRoute(
    builder: (context) => 
      PosPage(existingOrder: order)  ← Full Order object passed
  )
)
```

### 3. Order ID/Number Usage

| Property | Used For |
|----------|----------|
| `order.id` | Database identifier |
| `order.orderNumber` | UI display (e.g., "#ORD-001") |
| `order.status` | Filtering (active/history) |
| `order.items` | Display in card |
| `order.customer` | Display customer info |

### 4. Scrolling & Highlighting

**Current Status:** NOT IMPLEMENTED

**Available Infrastructure:**
- `ScrollController _activeOrdersScrollController`
- `ScrollController _historyOrdersScrollController`
- `PageStorageKey('active_orders_list')`
- `PageStorageKey('history_orders_list')`

**Could be Enhanced With:**
- Route parameter: `/orders/:orderId`
- Scroll animation to order position
- Highlight animation (background color flash)

### 5. Data Flow for Order Editing

```
OrdersPage._loadOrders()
    ↓
Loads list of Order objects
    ↓
User taps "Edit" button
    ↓
_navigateToOrderDetail(Order order)
    ↓
Navigator.push(PosPage(existingOrder: order))
    ↓
PosPage._loadExistingOrder(order)
    ├─ Convert order items to cart items
    ├─ Match with menu items
    ├─ Load customer info
    ├─ Load order notes
    └─ Open cart sheet
    ↓
User saves/completes
    ↓
Navigator.pop(context, true)
    ↓
OrdersPage catches return
    ↓
_loadOrders(showLoading: false)
    ↓
UI updates with new state
```

### 6. GoRouter Extension Methods

**Available:**
```dart
ref.read(appRouterProvider).goToOrders()
context.read(appRouterProvider).goToOrders()
context.go('/orders')  // Direct call
```

**Location:** `/Users/macbook/Projects/github/P/oishimenu-app-flutter/lib/core/router/app_router.dart` (Line 171)

### 7. Navigation Patterns Used

| Pattern | Example | When Used |
|---------|---------|-----------|
| GoRouter direct | `context.go('/orders')` | Simple route changes |
| Router extension | `ref.read(appRouterProvider).goToOrders()` | Type-safe access |
| Material Navigator | `Navigator.push(MaterialPageRoute(...))` | Pass complex objects |
| No GoRouter parameters | ❌ Not used for orders | - |

### 8. Critical Files

| File | Purpose | Key Lines |
|------|---------|-----------|
| `app_router.dart` | Route definitions | 112-115 (orders route) |
| `orders_page.dart` | Orders list display | 774-785 (navigation logic) |
| `pos_page.dart` | Order editing | 41-207 (order loading) |
| `recent_orders.dart` | Dashboard widget | 64 (nav to orders) |
| `order.dart` | Data model | N/A |

### 9. Order Status Values

```dart
enum OrderStatus {
  pending,      // Not started
  confirmed,    // Confirmed by staff
  preparing,    // Being made
  ready,        // Ready for pickup/delivery
  delivered,    // Completed
  cancelled,    // Cancelled
}
```

### 10. Return Value Pattern

```dart
Navigator.push(...).then((result) {
  if (result == true) {
    _loadOrders(showLoading: false);  // Refresh list
  }
});
```

**Means:**
- Return `true` = Changes made, reload UI
- Return `false/null` = No changes, don't reload

---

## How to Use This Info

### To Navigate to Orders:
```dart
// Option 1: Direct
context.go('/orders');

// Option 2: Extension method
ref.read(appRouterProvider).goToOrders();
```

### To Edit an Order:
```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => PosPage(existingOrder: order),
  ),
).then((result) {
  if (result == true) {
    _loadOrders(showLoading: false);
  }
});
```

### To Get Order ID After Navigation:
```dart
// Order object is available in PosPage
widget.existingOrder?.id       // Database ID
widget.existingOrder?.orderNumber  // Display number
```

---

## Limitations & Workarounds

### Limitation 1: Can't Pass OrderID via URL
**Problem:** Orders route doesn't accept ID parameter
**Workaround:** Use Material Navigator with full Order object

### Limitation 2: No Built-in Scroll-to-Order
**Problem:** Can't jump to specific order when navigating
**Workaround:** Add parameter to OrdersPage, implement scroll logic

### Limitation 3: No Highlight Feature
**Problem:** Can't visually highlight a specific order
**Workaround:** Add highlightOrderId parameter and animation

---

## Code Snippets

### Navigate to Orders (Simple)
```dart
context.go('/orders');
```

### Navigate to Edit Order
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

### Load Order in POS Page
```dart
if (widget.existingOrder != null) {
  _loadExistingOrder(widget.existingOrder!);
  _showEditingTransition();
}
```

### Reload Orders After Edit
```dart
final orderService = ref.read(supabaseOrderServiceProvider);
await orderService.updateOrder(updatedOrder);
ref.read(activeOrdersCountProvider.notifier).decrementCount();
Navigator.pop(context, true);  // Return true to trigger reload
```

---

## Related Routes

```
/dashboard          → Main dashboard
/menu               → Menu management
/orders             → Orders list (THIS ONE)
/pos                → Point of sale (used for editing orders)
/analytics          → Analytics
/finance            → Finance reports
/settings           → App settings
/login              → Login page
/signup             → Sign up page
```

