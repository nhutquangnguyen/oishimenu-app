// ========================================
// HYBRID SYNC ORDERS PAGE
// ========================================
// Updated OrdersPage using the new HybridSyncManager for simplified real-time sync

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../models/order.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../../core/sync/hybrid_sync_manager.dart';
import '../../../../core/sync/sync_events.dart';
import '../../../pos/presentation/pages/pos_page.dart';
import '../../../checkout/presentation/pages/checkout_page.dart';

class OrdersPageHybrid extends ConsumerStatefulWidget {
  const OrdersPageHybrid({super.key});

  @override
  ConsumerState<OrdersPageHybrid> createState() => _OrdersPageHybridState();
}

class _OrdersPageHybridState extends ConsumerState<OrdersPageHybrid>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {

  late TabController _tabController;
  late HybridSyncManager _syncManager;

  // State management
  List<Order> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Sync event subscription
  StreamSubscription<SyncEvent>? _syncEventsSubscription;

  // App lifecycle tracking
  bool _isAppActive = true;

  // Scroll controllers
  final ScrollController _activeOrdersScrollController = ScrollController();
  final ScrollController _historyOrdersScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    _initializeHybridSync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final wasActive = _isAppActive;
    _isAppActive = state == AppLifecycleState.resumed;

    if (!wasActive && _isAppActive) {
      // App became active - notify sync manager
      _syncManager.setAppForegroundState(true);
    } else if (wasActive && !_isAppActive) {
      // App became inactive
      _syncManager.setAppForegroundState(false);
    }
  }

  /// Initialize hybrid sync manager and load initial data
  Future<void> _initializeHybridSync() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Initialize sync manager
      _syncManager = HybridSyncManager();
      if (!_syncManager.isInitialized) {
        await _syncManager.initialize();
      }

      // Listen to sync events
      _setupSyncEventListeners();

      // Load initial data
      await _loadOrders();

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize sync: $e';
        _isLoading = false;
      });
    }
  }

  /// Setup sync event listeners
  void _setupSyncEventListeners() {
    _syncEventsSubscription = _syncManager.syncEvents.listen(_handleSyncEvent);
  }

  /// Handle sync events from HybridSyncManager
  void _handleSyncEvent(SyncEvent event) {
    if (!mounted) return;

    switch (event.type) {
      case SyncEventType.dataUpdated:
        // Full data refresh from server
        _handleDataUpdated(event);
        break;

      case SyncEventType.orderCreated:
        // New order created (locally or remotely)
        _handleOrderCreated(event);
        break;

      case SyncEventType.orderUpdated:
        // Order updated (replace optimistic with server data)
        _handleOrderUpdated(event);
        break;

      case SyncEventType.itemCompletionToggled:
        // Item completion changed locally
        _handleItemCompletionToggled(event);
        break;

      case SyncEventType.itemCompletionConfirmed:
        // Item completion confirmed on server
        _handleItemCompletionConfirmed(event);
        break;

      case SyncEventType.orderStatusUpdated:
        // Order status changed locally
        _handleOrderStatusUpdated(event);
        break;

      case SyncEventType.orderStatusConfirmed:
        // Order status confirmed on server
        _handleOrderStatusConfirmed(event);
        break;

      case SyncEventType.error:
      case SyncEventType.networkError:
        // Handle errors
        _handleSyncError(event);
        break;

      case SyncEventType.syncStarted:
        // Show sync indicator
        _showSyncIndicator(event.message);
        break;

      default:
        break;
    }
  }

  /// Handle full data update from server
  void _handleDataUpdated(SyncEvent event) {
    final freshOrders = event.data as List<Order>;

    setState(() {
      // Replace all data with fresh server data
      // But preserve local pending states for ongoing operations
      _orders = _mergeWithLocalPendingStates(freshOrders);
      _isLoading = false;
      _errorMessage = null;
    });

    _showSnackBar('Data synchronized (${freshOrders.length} orders)', isSuccess: true);
  }

  /// Handle new order creation
  void _handleOrderCreated(SyncEvent event) {
    final newOrder = event.data as Order;

    setState(() {
      // Add new order to the beginning of the list
      if (!_orders.any((order) => order.id == newOrder.id)) {
        _orders.insert(0, newOrder);
      }
    });

    if (event.isOptimistic) {
      _showSnackBar('Order created (saving...)', isSuccess: true);
    } else {
      _showSnackBar('Order created successfully', isSuccess: true);
    }
  }

  /// Handle order updates (replace optimistic with server data)
  void _handleOrderUpdated(SyncEvent event) {
    final newOrder = event.data as Order;
    final oldOrder = event.previousData as Order?;

    setState(() {
      if (oldOrder != null) {
        // Replace optimistic order with server order
        final index = _orders.indexWhere((order) => order.id == oldOrder.id);
        if (index != -1) {
          _orders[index] = newOrder;
        }
      } else {
        // General order update
        final index = _orders.indexWhere((order) => order.id == newOrder.id);
        if (index != -1) {
          _orders[index] = newOrder;
        }
      }
    });
  }

  /// Handle item completion toggle (immediate UI update)
  void _handleItemCompletionToggled(SyncEvent event) {
    final data = event.data as Map<String, dynamic>;
    final orderId = data['orderId'] as String;
    final itemId = data['itemId'] as String;
    final isCompleted = data['isCompleted'] as bool;
    final isLocalPending = data['isLocalPending'] as bool? ?? false;

    setState(() {
      _updateItemInOrders(orderId, itemId, (item) {
        return item.copyWith(
          isCompleted: isCompleted,
          isLocalPending: isLocalPending,
          completedAt: isCompleted ? DateTime.now() : null,
          syncError: null,
        );
      });
    });

    if (event.isOptimistic) {
      final status = isCompleted ? 'completed' : 'pending';
      _showSnackBar('Item marked as $status (saving...)', isSuccess: true);
    }
  }

  /// Handle item completion confirmation
  void _handleItemCompletionConfirmed(SyncEvent event) {
    final data = event.data as Map<String, dynamic>;
    final orderId = data['orderId'] as String;
    final itemId = data['itemId'] as String;

    setState(() {
      _updateItemInOrders(orderId, itemId, (item) {
        return item.copyWith(
          isLocalPending: false,
          syncError: null,
        );
      });
    });

    _showSnackBar('Item status saved successfully', isSuccess: true);
  }

  /// Handle order status updates
  void _handleOrderStatusUpdated(SyncEvent event) {
    final data = event.data as Map<String, dynamic>;
    final orderId = data['orderId'] as String;
    final status = data['status'] as String;
    final isLocalPending = data['isLocalPending'] as bool? ?? false;

    setState(() {
      final index = _orders.indexWhere((order) => order.id == orderId);
      if (index != -1) {
        _orders[index] = _orders[index].copyWith(
          status: OrderStatus.fromString(status),
          hasLocalChanges: isLocalPending,
        );
      }
    });

    if (event.isOptimistic) {
      _showSnackBar('Order status updated (saving...)', isSuccess: true);
    }
  }

  /// Handle order status confirmation
  void _handleOrderStatusConfirmed(SyncEvent event) {
    final data = event.data as Map<String, dynamic>;
    final orderId = data['orderId'] as String;

    setState(() {
      final index = _orders.indexWhere((order) => order.id == orderId);
      if (index != -1) {
        _orders[index] = _orders[index].copyWith(
          hasLocalChanges: false,
          syncError: null,
        );
      }
    });

    _showSnackBar('Order status saved successfully', isSuccess: true);
  }

  /// Handle sync errors
  void _handleSyncError(SyncEvent event) {
    // Handle specific error types
    if (event.data is Map<String, dynamic>) {
      final errorData = event.data as Map<String, dynamic>;

      // Revert optimistic item completion updates
      if (errorData.containsKey('orderId') && errorData.containsKey('itemId')) {
        final orderId = errorData['orderId'] as String;
        final itemId = errorData['itemId'] as String;

        setState(() {
          _updateItemInOrders(orderId, itemId, (item) {
            return item.copyWith(
              isCompleted: !(errorData['isCompleted'] ?? false),
              isLocalPending: false,
              syncError: 'Sync failed - tap to retry',
            );
          });
        });
      }

      // Handle order creation errors
      if (event.data is Order) {
        final orderData = event.data as Order;
        if (orderData.isLocalPending) {
          setState(() {
            final index = _orders.indexWhere((order) => order.id == orderData.id);
            if (index != -1) {
              _orders[index] = orderData.copyWith(
                syncError: event.message,
              );
            }
          });
        }
      }
    }

    _showSnackBar(
      event.message,
      isSuccess: false,
      action: SnackBarAction(
        label: 'Retry',
        onPressed: () => _syncManager.forceRefresh(),
      ),
    );
  }

  /// Load orders from the service (fallback method)
  Future<void> _loadOrders() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final orderService = ref.read(supabaseOrderServiceProvider);
      final orders = await orderService.getOrders(limit: 100);

      setState(() {
        _orders = orders;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load orders: $e';
        _isLoading = false;
      });
    }
  }

  /// Merge fresh server data with local pending states
  List<Order> _mergeWithLocalPendingStates(List<Order> freshOrders) {
    return freshOrders.map((freshOrder) {
      // Find corresponding local order
      final localOrder = _orders.firstWhere(
        (order) => order.id == freshOrder.id,
        orElse: () => freshOrder,
      );

      // If local order has no pending changes, use fresh data
      if (!localOrder.isLocalPending && !localOrder.hasLocalChanges) {
        return freshOrder;
      }

      // Merge: use fresh data but preserve local pending states
      final mergedItems = freshOrder.items.map((freshItem) {
        final localItem = localOrder.items.firstWhere(
          (item) => item.id == freshItem.id,
          orElse: () => freshItem,
        );

        // Preserve local pending state
        if (localItem.isLocalPending) {
          return localItem;
        }

        return freshItem;
      }).toList();

      return freshOrder.copyWith(
        items: mergedItems,
        isLocalPending: localOrder.isLocalPending,
        hasLocalChanges: localOrder.hasLocalChanges,
        syncError: localOrder.syncError,
      );
    }).toList();
  }

  /// Update specific item in orders list
  void _updateItemInOrders(String orderId, String itemId, OrderItem Function(OrderItem) updater) {
    final orderIndex = _orders.indexWhere((order) => order.id == orderId);
    if (orderIndex == -1) return;

    final order = _orders[orderIndex];
    final itemIndex = order.items.indexWhere((item) => item.id == itemId);
    if (itemIndex == -1) return;

    final updatedItems = List<OrderItem>.from(order.items);
    updatedItems[itemIndex] = updater(updatedItems[itemIndex]);

    _orders[orderIndex] = order.copyWith(items: updatedItems);
  }

  /// Show sync indicator
  void _showSyncIndicator(String message) {
    // Could show a subtle loading indicator in the app bar
    // For now, just log it
    debugPrint('🔄 Sync: $message');
  }

  /// Show snackbar with message
  void _showSnackBar(String message, {bool isSuccess = true, SnackBarAction? action}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        action: action,
        duration: Duration(seconds: isSuccess ? 2 : 4),
      ),
    );
  }

  // ========== USER ACTION HANDLERS ==========

  /// Handle item completion tap
  Future<void> _handleItemCompletionTap(Order order, OrderItem item) async {
    // Prevent multiple taps while syncing
    if (item.isLocalPending) {
      _showSnackBar('Item is syncing, please wait...', isSuccess: false);
      return;
    }

    try {
      await _syncManager.toggleItemCompletion(
        orderId: order.id,
        itemId: item.id,
        isCompleted: !item.isCompleted,
      );
    } catch (e) {
      // Error handling is done in _handleSyncError
      debugPrint('Toggle completion failed: $e');
    }
  }

  /// Handle order status change
  Future<void> _changeOrderStatus(Order order, OrderStatus newStatus) async {
    // Prevent multiple changes while syncing
    if (order.hasLocalChanges) {
      _showSnackBar('Order is syncing, please wait...', isSuccess: false);
      return;
    }

    try {
      await _syncManager.updateOrderStatus(
        orderId: order.id,
        status: newStatus,
      );
    } catch (e) {
      // Error handling is done in _handleSyncError
      debugPrint('Update order status failed: $e');
    }
  }

  /// Force refresh data
  Future<void> _forceRefresh() async {
    try {
      await _syncManager.forceRefresh();
    } catch (e) {
      _showSnackBar('Failed to refresh: $e', isSuccess: false);
    }
  }

  // ========== NAVIGATION METHODS ==========

  void _navigateToCheckout(Order order) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CheckoutPage(order: order),
      ),
    );

    if (result == true && mounted) {
      await _forceRefresh();
    }
  }

  void _navigateToPosWithOrder(Order order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PosPage(existingOrder: order),
      ),
    ).then((_) {
      _forceRefresh();
    });
  }

  // ========== UI BUILDERS ==========

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('orders.title'.tr()),
        ),
        body: _buildErrorView(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('orders.title'.tr()),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _forceRefresh,
            tooltip: 'Refresh',
          ),
          _buildSyncStatusIndicator(),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'orders.active'.tr(),
              icon: Icon(Icons.pending_actions),
            ),
            Tab(
              text: 'orders.history'.tr(),
              icon: Icon(Icons.history),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? _buildLoadingView()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildActiveOrdersTab(),
                _buildHistoryOrdersTab(),
              ],
            ),
    );
  }

  Widget _buildSyncStatusIndicator() {
    if (_syncManager.isSyncing) {
      return Container(
        margin: EdgeInsets.only(right: 16),
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return SizedBox.shrink();
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _initializeHybridSync,
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading orders...'),
        ],
      ),
    );
  }

  Widget _buildActiveOrdersTab() {
    final activeOrders = _orders.where((order) =>
      order.status != OrderStatus.delivered &&
      order.status != OrderStatus.cancelled
    ).toList();

    if (activeOrders.isEmpty) {
      return _buildEmptyView('No active orders');
    }

    return RefreshIndicator(
      onRefresh: _forceRefresh,
      child: ListView.builder(
        controller: _activeOrdersScrollController,
        padding: EdgeInsets.all(8),
        itemCount: activeOrders.length,
        itemBuilder: (context, index) {
          return _buildOrderCard(activeOrders[index]);
        },
      ),
    );
  }

  Widget _buildHistoryOrdersTab() {
    final historyOrders = _orders.where((order) =>
      order.status == OrderStatus.delivered ||
      order.status == OrderStatus.cancelled
    ).toList();

    if (historyOrders.isEmpty) {
      return _buildEmptyView('No order history');
    }

    return RefreshIndicator(
      onRefresh: _forceRefresh,
      child: ListView.builder(
        controller: _historyOrdersScrollController,
        padding: EdgeInsets.all(8),
        itemCount: historyOrders.length,
        itemBuilder: (context, index) {
          return _buildOrderCard(historyOrders[index]);
        },
      ),
    );
  }

  Widget _buildEmptyView(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: 2,
      child: Column(
        children: [
          _buildOrderHeader(order),
          ...order.items.map((item) => _buildOrderItem(order, item)),
          _buildOrderFooter(order),
        ],
      ),
    );
  }

  Widget _buildOrderHeader(Order order) {
    Color statusColor = _getStatusColor(order.status);

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order #${order.orderNumber}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                order.customer.name,
                style: TextStyle(color: Colors.grey[600]),
              ),
              if (order.tableNumber != null)
                Text(
                  'Table ${order.tableNumber}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  order.status.value,
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              SizedBox(height: 4),
              Text(
                '\$${order.total.toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (order.isLocalPending || order.hasLocalChanges)
                Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 4),
                    Text('Syncing...', style: TextStyle(fontSize: 10, color: Colors.orange)),
                  ],
                ),
              if (order.syncError != null)
                Row(
                  children: [
                    Icon(Icons.error, size: 12, color: Colors.red),
                    SizedBox(width: 4),
                    Text('Sync failed', style: TextStyle(fontSize: 10, color: Colors.red)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(Order order, OrderItem item) {
    return ListTile(
      leading: Checkbox(
        value: item.isCompleted,
        onChanged: item.isLocalPending ? null : (bool? value) {
          if (value != null) {
            _handleItemCompletionTap(order, item);
          }
        },
      ),
      title: Text(item.menuItemName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quantity: ${item.quantity}'),
          if (item.isLocalPending)
            Row(
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Syncing...', style: TextStyle(color: Colors.orange)),
              ],
            ),
          if (item.syncError != null)
            Row(
              children: [
                Icon(Icons.error, size: 16, color: Colors.red),
                SizedBox(width: 4),
                Text(
                  item.syncError!,
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ),
        ],
      ),
      trailing: item.isCompleted
          ? Icon(Icons.check_circle, color: Colors.green)
          : Icon(Icons.radio_button_unchecked, color: Colors.grey),
    );
  }

  Widget _buildOrderFooter(Order order) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat('MMM dd, hh:mm a').format(order.createdAt),
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          Row(
            children: [
              if (order.status == OrderStatus.pending || order.status == OrderStatus.confirmed)
                ElevatedButton(
                  onPressed: () => _navigateToPosWithOrder(order),
                  child: Text('Edit'),
                ),
              SizedBox(width: 8),
              if (order.status != OrderStatus.delivered && order.status != OrderStatus.cancelled)
                ElevatedButton(
                  onPressed: () => _navigateToCheckout(order),
                  child: Text('Checkout'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.purple;
      case OrderStatus.ready:
        return Colors.green;
      case OrderStatus.delivered:
        return Colors.grey;
      case OrderStatus.cancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _syncEventsSubscription?.cancel();
    _activeOrdersScrollController.dispose();
    _historyOrdersScrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);

    // Don't dispose the sync manager here as it's a singleton
    // It will be disposed when the app shuts down

    super.dispose();
  }
}