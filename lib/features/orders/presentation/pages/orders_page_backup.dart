import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../models/order.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../../core/events/order_events.dart';
import '../../../../core/sync/cursor_sync_manager.dart';
import '../../../pos/presentation/pages/pos_page.dart';
import '../../../checkout/presentation/pages/checkout_page.dart';

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;

  List<Order> _orders = [];
  bool _isLoading = true;

  // Track completed items (orderId -> Set of item IDs)
  // TODO: Remove this after database migration is completed
  final Map<String, Set<String>> _completedItems = <String, Set<String>>{};

  // Timer for periodic refresh
  Timer? _refreshTimer;

  // Real-time event subscriptions
  StreamSubscription<OrderEventType>? _orderEventsSubscription;
  StreamSubscription<SyncEvent>? _syncEventsSubscription;

  // App lifecycle state tracking for smart refresh
  bool _isAppActive = true;

  // Debug tracking for syncing duration
  Map<String, DateTime> _syncStartTimes = {}; // itemId -> sync start time

  // Track last sync time to avoid excessive syncing
  DateTime? _lastSyncTime;

  // Scroll controllers to preserve scroll position
  final ScrollController _activeOrdersScrollController = ScrollController();
  final ScrollController _historyOrdersScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    // Clear any old state to prevent type conflicts
    _completedItems.clear();
    _loadOrders();
    _startRefreshTimer();
    _setupRealtimeListeners();
  }

  // Update item completion status in existing orders without reordering
  // This preserves the exact order of menu items within each order card
  Future<void> _updateItemCompletionInList() async {
    if (!mounted) return;

    // Check if any items are currently syncing
    final syncingItems = _orders
        .expand((order) => order.items)
        .where((item) => item.isSyncing)
        .map((item) => item.menuItemName)
        .toList();

    if (syncingItems.isNotEmpty) {
      debugPrint('🔒 [UPDATE COMPLETION] Blocking sync - items currently syncing: ${syncingItems.join(", ")}');
      return;
    }

    // Avoid excessive syncing - limit to once every 500ms for better responsiveness
    final now = DateTime.now();
    final oldLastSyncTime = _lastSyncTime;

    if (_lastSyncTime != null &&
        now.difference(_lastSyncTime!).inMilliseconds < 500) {
      debugPrint('🚫 [ORDERS PAGE] Sync skipped - debounce active (500ms)');
      return;
    }

    // Determine sync trigger source for better debugging
    final timeSinceLastSync = oldLastSyncTime != null
        ? now.difference(oldLastSyncTime).inSeconds
        : 999;

    _lastSyncTime = now;

    if (timeSinceLastSync > 10) {
      debugPrint('📡 [ORDERS PAGE] Fallback sync - fetching fresh data from database (${timeSinceLastSync}s ago)');
    } else {
      debugPrint('🌐 [ORDERS PAGE] Real-time sync - updating item completion status');
    }

    try {
      final orderService = ref.read(supabaseOrderServiceProvider);

      // Get fresh order data
      final freshOrders = await orderService.getOrders(limit: 100);

      if (!mounted) return;

      setState(() {
        // Merge fresh completion data while preserving syncing states
        for (int i = 0; i < _orders.length; i++) {
          final currentOrder = _orders[i];
          final freshOrder = freshOrders.firstWhere(
            (order) => order.id == currentOrder.id,
            orElse: () => currentOrder,
          );

          // Check if this order has any syncing items that need protection
          final hasSyncingItems = currentOrder.items.any((item) => item.isSyncing);

          if (hasSyncingItems) {
            debugPrint('🛡️ [UPDATE COMPLETION] Order ${currentOrder.orderNumber} has syncing items - skipping merge');
            continue; // Skip updating this order entirely to preserve syncing states
          }

          // Safe to update - no syncing items in this order
          final updatedItems = <OrderItem>[];
          for (int j = 0; j < currentOrder.items.length; j++) {
            final currentItem = currentOrder.items[j];
            final freshItem = freshOrder.items.firstWhere(
              (item) => item.id == currentItem.id,
              orElse: () => currentItem,
            );

            // Only update completion fields, preserve all local state
            final updatedItem = currentItem.copyWith(
              isCompleted: freshItem.isCompleted,
              completedAt: freshItem.completedAt,
            );
            updatedItems.add(updatedItem);
          }

          _orders[i] = currentOrder.copyWith(items: updatedItems);
        }
      });

      // Also clear local state to ensure fresh data takes precedence
      _completedItems.clear();

    } catch (e) {
      // Fallback to simple setState to show local changes
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _setupRealtimeListeners() {
    // Listen to local order events with smart handling
    _orderEventsSubscription = OrderEvents.orderChanges.listen((event) {
      switch (event) {
        case OrderEventType.created:
        case OrderEventType.deleted:
          if (mounted) {
            _loadOrders(showLoading: false);
          }
          break;
        case OrderEventType.updated:
          if (mounted) {
            debugPrint('📡 [ORDERS PAGE] Local order update - skipping database sync during user action');
            // Skip database sync for local events to preserve syncing states
            // The real-time subscription will handle actual data updates
          }
          break;
      }
    });

    // Listen to sync events (remote updates from other devices)
    final syncManager = CursorSyncManager();
    _syncEventsSubscription = syncManager.syncEvents.listen((event) {
      // Handle specific event types
      switch (event.type) {
        case SyncEventType.itemCompletionUpdated:
          debugPrint('🌐 [ORDERS PAGE] Real-time event received - item completion updated');
          if (mounted) {
            // Check if any items are currently syncing before updating
            final hasSyncingItems = _orders.any((order) =>
              order.items.any((item) => item.isSyncing));

            if (hasSyncingItems) {
              debugPrint('⏸️ [ORDERS PAGE] Skipping real-time sync - items are currently syncing');
            } else {
              debugPrint('✅ [ORDERS PAGE] No syncing items - proceeding with real-time sync');
              _updateItemCompletionInList();
            }
          }
          break;
        case SyncEventType.orderCreated:
        case SyncEventType.orderDeleted:
        case SyncEventType.gapHealed:
          if (mounted) {
            _loadOrders(showLoading: false);
          }
          break;
        case SyncEventType.realtimeUpdate:
          if (mounted) {
            // Check if any items are currently syncing before doing full reload
            final hasSyncingItems = _orders.any((order) =>
              order.items.any((item) => item.isSyncing));

            if (hasSyncingItems) {
              debugPrint('🛡️ [ORDERS PAGE] Blocking full reload - items are syncing');
            } else {
              debugPrint('✅ [ORDERS PAGE] No syncing items - proceeding with full reload');
              _loadOrders(showLoading: false);
            }
          }
          break;
        case SyncEventType.orderUpdated:
          if (mounted) {
            _updateItemCompletionInList();
          }
          break;
      }
    });

    // Add periodic sync as fallback ONLY when real-time might be failing
    // Check every 30 seconds if we need to fallback to polling
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        // Only poll if we haven't received a real-time event recently
        final now = DateTime.now();
        final timeSinceLastSync = _lastSyncTime != null
            ? now.difference(_lastSyncTime!).inSeconds
            : 999;

        // If it's been more than 15 seconds since last sync, do a fallback check
        if (timeSinceLastSync > 15) {
          debugPrint('📡 [ORDERS PAGE] Fallback sync - no real-time updates in ${timeSinceLastSync}s');
          _updateItemCompletionInList();
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _startRefreshTimer() {
    // 🚀 COST OPTIMIZATION: Reduced from 30s to 5 minutes + smart app lifecycle pausing
    // Only refresh when app is active to dramatically reduce database costs
    // This reduces from 2 calls/minute to 0.2 calls/minute when active, 0 when inactive!
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted && _isAppActive) {
        _loadOrders(showLoading: false); // Background refresh only when app is active
      }
    });
  }

  void _pauseRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void _resumeRefreshTimer() {
    if (_refreshTimer == null) {
      _startRefreshTimer();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _orderEventsSubscription?.cancel();
    _syncEventsSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _activeOrdersScrollController.dispose();
    _historyOrdersScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 🚀 SMART REFRESH: Pause all database polling when app is not active
    // This can reduce database calls by 80-90% during background periods
    switch (state) {
      case AppLifecycleState.resumed:
        _isAppActive = true;
        _resumeRefreshTimer();
        _loadOrders(showLoading: false); // Fresh data when user returns
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _isAppActive = false;
        _pauseRefreshTimer(); // Stop all background polling
        break;
    }
  }

  Future<void> _loadOrders({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final orderService = ref.read(supabaseOrderServiceProvider);

      // Clear local state to get fresh data from database
      _completedItems.clear();

      // Reset sync time to allow immediate updates
      _lastSyncTime = null;

      // 🚀 PERFORMANCE FIX: Add pagination limit to prevent loading too many historical orders
      // This limits the database response size and improves loading speed
      final orders = await orderService.getOrders(
        limit: 100, // Limit to most recent 100 orders for better performance
      );

      if (mounted) {
        setState(() {
          _orders = orders;
          if (showLoading) {
            _isLoading = false;
          }
        });
      }

      // Debug: Loaded ${orders.length} orders with pagination limit
    } catch (e) {
      // Debug: Error loading orders: $e
      if (showLoading && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Order> get _activeOrders {
    return _orders.where((order) =>
      order.status != OrderStatus.delivered &&
      order.status != OrderStatus.cancelled
    ).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt)); // Ascending by time - older first
  }

  List<Order> get _historyOrders {
    return _orders.where((order) =>
      order.status == OrderStatus.delivered ||
      order.status == OrderStatus.cancelled
    ).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🚀 COST OPTIMIZATION: Add manual refresh option since auto-refresh is now less frequent
      appBar: AppBar(
        title: Text('orders_page.title'.tr()),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'orders_page.refresh_tooltip'.tr(),
            onPressed: () => _loadOrders(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blue[700],
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Colors.blue[700],
              indicatorWeight: 3,
              tabs: [
                Tab(text: 'orders_page.processing_tab'.tr()),
                Tab(text: 'orders_page.history_tab'.tr()),
              ],
            ),
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildActiveOrdersTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOrdersTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_activeOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'orders_page.no_orders'.tr(),
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadOrders,
              icon: const Icon(Icons.refresh),
              label: Text('orders_page.reload_button'.tr()),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        key: const PageStorageKey('active_orders_list'),
        controller: _activeOrdersScrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _activeOrders.length,
        itemBuilder: (context, index) {
          final order = _activeOrders[index];
          return _buildActiveOrderCard(order, index);
        },
      ),
    );
  }

  Widget _buildActiveOrderCard(Order order, int index) {
    // Alternate colors for better distinction
    final bool isEven = index % 2 == 0;
    final Color cardColor = isEven ? Colors.blue[50]! : Colors.orange[50]!;
    final Color borderColor = isEven ? Colors.blue[200]! : Colors.orange[200]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Clickable order number
                      InkWell(
                        onTap: () => _navigateToCheckoutWithOrder(order),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.blue[300]!, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long, size: 16, color: Colors.blue[700]),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  order.orderNumber,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue[800],
                                    letterSpacing: 0.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(order.createdAt),
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Cancel button
                IconButton(
                  onPressed: () => _showCancelOrderDialog(order),
                  icon: const Icon(Icons.cancel, color: Colors.red, size: 28),
                  tooltip: 'orders_page.cancel_order_tooltip'.tr(),
                ),
              ],
            ),
            const Divider(height: 24),

            // Customer info
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatCustomerInfo(order),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (order.tableNumber != null) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.table_restaurant, size: 16, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Text(order.tableNumber!),
                ],
                if (order.platform.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.delivery_dining, size: 16, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Text(order.platform),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Order notes (if exists)
            if (order.notes != null && order.notes!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber[200]!, width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note_alt_outlined, size: 16, color: Colors.amber[800]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.notes!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Order items
            ...order.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildActiveOrderItem(order, index, item);
            }),

            const SizedBox(height: 8),

            // Add Menu Item button
            Container(
              width: double.infinity,
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
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _navigateToPosWithOrder(order),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.restaurant_menu,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'orders_page.add_items_button'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const Divider(height: 24),

            // Total and actions
            Row(
              children: [
                Expanded(
                  child: Text(
                    'orders_page.total_label'.tr(namedArgs: {'amount': order.total.toStringAsFixed(0)}),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _markOrderDone(order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.payment),
                  label: Text('orders_page.checkout_button'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveOrderItem(Order order, int index, OrderItem item) {
    // Database state takes precedence, local state only for immediate feedback
    final isCompleted = item.isCompleted || (_completedItems[order.id]?.contains(item.id) ?? false);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCompleted ? Colors.green[300]! : Colors.grey[200]!,
          width: isCompleted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.menuItemName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                        color: isCompleted ? Colors.grey[600] : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Mark Done / Done button
                    InkWell(
                      onTap: () {
                        _handleItemCompletionTap(order, item);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: _buildCompletionButton(item),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => _decreaseQuantity(order, index),
                    icon: const Icon(Icons.remove_circle_outline),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${item.quantity}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _increaseQuantity(order, index),
                    icon: const Icon(Icons.add_circle_outline),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          if (item.selectedOptions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: item.selectedOptions.map((option) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '+ ${option.optionName}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )).toList(),
              ),
            ),
          ],
          if (item.notes != null && item.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.amber[200]!, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_note, size: 14, color: Colors.amber[800]),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        item.notes!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[800],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Text(
              '${item.subtotal.toStringAsFixed(0)}đ',
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_historyOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'orders_page.no_history'.tr(),
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadOrders,
              icon: const Icon(Icons.refresh),
              label: Text('orders_page.reload_button'.tr()),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        key: const PageStorageKey('history_orders_list'),
        controller: _historyOrdersScrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _historyOrders.length,
        itemBuilder: (context, index) {
          final order = _historyOrders[index];
          return _buildHistoryOrderCard(order);
        },
      ),
    );
  }

  Widget _buildHistoryOrderCard(Order order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => _showOrderDetailsDialog(order), // 🆕 Add tap handler to show order details
        leading: CircleAvatar(
          backgroundColor: order.status == OrderStatus.delivered
              ? Colors.green[100]
              : Colors.red[100],
          child: Icon(
            order.status == OrderStatus.delivered
                ? Icons.check
                : Icons.close,
            color: order.status == OrderStatus.delivered
                ? Colors.green[700]
                : Colors.red[700],
          ),
        ),
        title: Text(
          order.orderNumber,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${order.customer.name} • ${order.items.length} món${order.platform.isNotEmpty ? " • ${order.platform}" : ""}'),
            Text(
              _formatDateTime(order.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: SizedBox(
          width: 100,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      '${order.total.toStringAsFixed(0)}đ',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // 🆕 Compact visual hint that the card is tappable
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Colors.grey[400],
                  ),
                ],
              ),
              const SizedBox(height: 2),
              _buildCompactStatusChip(order.status),
            ],
          ),
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildStatusChip(OrderStatus status) {
    Color bgColor;
    String label;

    switch (status) {
      case OrderStatus.pending:
        bgColor = Colors.orange[100]!;
        label = 'orders_page.status_pending'.tr();
        break;
      case OrderStatus.confirmed:
        bgColor = Colors.blue[100]!;
        label = 'orders_page.status_confirmed'.tr();
        break;
      case OrderStatus.preparing:
        bgColor = Colors.purple[100]!;
        label = 'orders_page.status_preparing'.tr();
        break;
      case OrderStatus.ready:
        bgColor = Colors.teal[100]!;
        label = 'orders_page.status_ready'.tr();
        break;
      case OrderStatus.delivered:
        bgColor = Colors.green[100]!;
        label = 'orders_page.status_delivered'.tr();
        break;
      case OrderStatus.cancelled:
        bgColor = Colors.red[100]!;
        label = 'orders_page.status_cancelled'.tr();
        break;
      default:
        bgColor = Colors.grey[100]!;
        label = status.value;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  /// 🆕 Compact version of status chip for trailing section to prevent overflow
  Widget _buildCompactStatusChip(OrderStatus status) {
    Color bgColor;
    String label;

    switch (status) {
      case OrderStatus.pending:
        bgColor = Colors.orange[100]!;
        label = 'orders_page.status_pending'.tr();
        break;
      case OrderStatus.confirmed:
        bgColor = Colors.blue[100]!;
        label = 'orders_page.status_confirmed'.tr();
        break;
      case OrderStatus.preparing:
        bgColor = Colors.purple[100]!;
        label = 'orders_page.status_preparing'.tr();
        break;
      case OrderStatus.ready:
        bgColor = Colors.teal[100]!;
        label = 'orders_page.status_ready'.tr();
        break;
      case OrderStatus.delivered:
        bgColor = Colors.green[100]!;
        label = 'orders_page.status_delivered'.tr();
        break;
      case OrderStatus.cancelled:
        bgColor = Colors.red[100]!;
        label = 'orders_page.status_cancelled'.tr();
        break;
      default:
        bgColor = Colors.grey[100]!;
        label = status.value;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.grey[800],
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 60) {
      return 'orders_page.time_minutes_ago'.tr(namedArgs: {'minutes': diff.inMinutes.toString()});
    } else if (diff.inHours < 24) {
      return 'orders_page.time_hours_ago'.tr(namedArgs: {'hours': diff.inHours.toString()});
    } else {
      return 'orders_page.time_days_ago'.tr(namedArgs: {'days': diff.inDays.toString()});
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatCustomerInfo(Order order) {
    final customer = order.customer;
    final hasName = customer.name.trim().isNotEmpty;
    final hasPhone = customer.phone?.trim().isNotEmpty ?? false;

    if (hasName && hasPhone) {
      return '${customer.name} - ${customer.phone}';
    } else if (hasName) {
      return customer.name;
    } else if (hasPhone) {
      return customer.phone!;
    } else {
      return 'orders_page.unknown_customer'.tr();
    }
  }

  Future<void> _increaseQuantity(Order order, int itemIndex) async {
    try {
      // Update the item quantity and reset completion status
      final updatedItems = List<OrderItem>.from(order.items);
      final item = updatedItems[itemIndex];
      final newQuantity = item.quantity + 1;
      final itemNewSubtotal = (item.basePrice + item.selectedOptions.fold(0.0, (sum, opt) => sum + opt.price)) * newQuantity;

      updatedItems[itemIndex] = item.copyWith(
        quantity: newQuantity,
        subtotal: itemNewSubtotal,
        isCompleted: false, // Reset completion status when quantity changes
        completedAt: null,
      );

      // Calculate new order total
      final orderNewTotal = updatedItems.fold(0.0, (sum, item) => sum + item.subtotal);

      // Update the order
      final updatedOrder = order.copyWith(
        items: updatedItems,
        subtotal: orderNewTotal,
        total: orderNewTotal,
        updatedAt: DateTime.now(),
      );

      // 🚀 PERFORMANCE FIX: Optimistic update - update UI immediately
      final orderIndex = _orders.indexWhere((o) => o.id == order.id);
      if (orderIndex != -1) {
        setState(() {
          _orders[orderIndex] = updatedOrder;
        });
      }

      // Update database in background (no reload needed!)
      final orderService = ref.read(supabaseOrderServiceProvider);
      await orderService.updateOrder(updatedOrder);

      // Debug: Quantity increased with optimistic update - no full reload!
    } catch (e) {
      // 🔄 Error occurred - revert UI and reload data
      // Debug: Update failed, reverting optimistic changes...
      await _loadOrders(showLoading: false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('orders_page.update_quantity_error'.tr(namedArgs: {'error': e.toString()})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _decreaseQuantity(Order order, int itemIndex) async {
    try {
      final item = order.items[itemIndex];

      // If quantity is 1, remove the item
      if (item.quantity <= 1) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('orders_page.confirm_delete_title'.tr()),
            content: Text('orders_page.confirm_delete_message'.tr(namedArgs: {'item': item.menuItemName})),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('orders_page.cancel_button'.tr()),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('orders_page.delete_button'.tr()),
              ),
            ],
          ),
        );

        if (confirmed != true) return;

        // Remove the item
        final updatedItems = List<OrderItem>.from(order.items)..removeAt(itemIndex);

        // If no items left, delete or cancel the order
        if (updatedItems.isEmpty) {
          if (!mounted) return;

          final deleteOrder = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('orders_page.empty_order_title'.tr()),
              content: Text('orders_page.empty_order_message'.tr()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('orders_page.keep_button'.tr()),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: Text('orders_page.cancel_order_button'.tr()),
                ),
              ],
            ),
          );

          if (deleteOrder == true) {
            final updatedOrder = order.copyWith(
              status: OrderStatus.cancelled,
              updatedAt: DateTime.now(),
            );
            final orderService = ref.read(supabaseOrderServiceProvider);
      await orderService.updateOrder(updatedOrder);
          }
          await _loadOrders(showLoading: false);
          return;
        }

        // Calculate new total
        final newSubtotal = updatedItems.fold(0.0, (sum, item) => sum + item.subtotal);

        final updatedOrder = order.copyWith(
          items: updatedItems,
          subtotal: newSubtotal,
          total: newSubtotal,
          updatedAt: DateTime.now(),
        );

        final orderService = ref.read(supabaseOrderServiceProvider);
      await orderService.updateOrder(updatedOrder);
      } else {
        // Decrease quantity
        final updatedItems = List<OrderItem>.from(order.items);
        final newQuantity = item.quantity - 1;
        final newSubtotal = (item.basePrice + item.selectedOptions.fold(0.0, (sum, opt) => sum + opt.price)) * newQuantity;

        updatedItems[itemIndex] = OrderItem(
          id: item.id,
          menuItemId: item.menuItemId,
          menuItemName: item.menuItemName,
          basePrice: item.basePrice,
          quantity: newQuantity,
          selectedOptions: item.selectedOptions,
          subtotal: newSubtotal,
        );

        // Calculate new order total
        final newTotal = updatedItems.fold(0.0, (sum, item) => sum + item.subtotal);

        final updatedOrder = order.copyWith(
          items: updatedItems,
          subtotal: newTotal,
          total: newTotal,
          updatedAt: DateTime.now(),
        );

        // 🚀 PERFORMANCE FIX: Optimistic update for decrease quantity
        final orderIndex = _orders.indexWhere((o) => o.id == order.id);
        if (orderIndex != -1) {
          setState(() {
            _orders[orderIndex] = updatedOrder;
          });
        }

        final orderService = ref.read(supabaseOrderServiceProvider);
      await orderService.updateOrder(updatedOrder);

        // Debug: Quantity decreased with optimistic update - no full reload!
      }
    } catch (e) {
      // 🔄 Error occurred - revert UI and reload data
      // Debug: Update failed, reverting optimistic changes...
      await _loadOrders(showLoading: false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('orders_page.update_quantity_error'.tr(namedArgs: {'error': e.toString()})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markOrderDone(Order order) async {
    // Navigate to checkout page
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutPage(order: order),
      ),
    );

    // Reload orders if checkout was successful
    if (result == true && mounted) {
      await _loadOrders(showLoading: false);
    }
  }

  Future<void> _navigateToCheckoutWithOrder(Order order) async {
    // Navigate to checkout page when order ID is clicked
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutPage(order: order),
      ),
    );

    // Reload orders if checkout was successful
    if (result == true && mounted) {
      await _loadOrders(showLoading: false);
    }
  }

  void _navigateToPosWithOrder(Order order) {
    // Navigate to POS page with the existing order
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PosPage(existingOrder: order),
      ),
    ).then((_) {
      // Reload orders when returning from POS
      _loadOrders(showLoading: false);
    });
  }

  Future<void> _toggleItemCompletion(Order order, String itemId, OrderItem item) async {
    // Determine new completion status
    final currentlyCompleted = item.isCompleted || (_completedItems[order.id]?.contains(itemId) ?? false);
    final newCompletedStatus = !currentlyCompleted;

    debugPrint('🔄 [TOGGLE COMPLETION] Starting sync process for ${item.menuItemName}');
    debugPrint('🔄 [TOGGLE COMPLETION] New completion status: $newCompletedStatus');

    // Step 1: Immediately update UI with syncing state
    setState(() {
      // Update local completion state for immediate feedback
      if (newCompletedStatus) {
        _completedItems.putIfAbsent(order.id, () => <String>{}).add(itemId);
      } else {
        _completedItems[order.id]?.remove(itemId);
      }

      // Update the actual order item with syncing state
      final orderIndex = _orders.indexWhere((o) => o.id == order.id);
      if (orderIndex != -1) {
        final currentOrder = _orders[orderIndex];
        final itemIndex = currentOrder.items.indexWhere((i) => i.id == itemId);

        if (itemIndex != -1) {
          final updatedItems = List<OrderItem>.from(currentOrder.items);
          updatedItems[itemIndex] = item.copyWith(
            isCompleted: newCompletedStatus,
            completedAt: newCompletedStatus ? DateTime.now() : null,
            isSyncing: true, // Show syncing indicator
            syncError: null, // Clear any previous errors
          );

          _orders[orderIndex] = currentOrder.copyWith(items: updatedItems);

          // Track sync start time for this item
          _syncStartTimes[itemId] = DateTime.now();
          debugPrint('✅ [TOGGLE COMPLETION] UI updated with isSyncing: true - timer started');
        }
      }
    });

    // Step 2: Update database with minimum 2-second syncing time
    final syncStartTime = DateTime.now();
    const minimumSyncDuration = Duration(seconds: 10);

    try {
      final orderService = ref.read(supabaseOrderServiceProvider);

      // Create updated item with new completion status
      final updatedItem = item.copyWith(
        isCompleted: newCompletedStatus,
        completedAt: newCompletedStatus ? DateTime.now() : null,
      );

      // Create updated order with the modified item
      final updatedItems = List<OrderItem>.from(order.items);
      final itemIndex = updatedItems.indexWhere((orderItem) => orderItem.id == itemId);
      if (itemIndex != -1) {
        updatedItems[itemIndex] = updatedItem;
      }

      final updatedOrder = order.copyWith(
        items: updatedItems,
        updatedAt: DateTime.now(),
      );

      // Update the order in database (this will trigger real-time sync)
      debugPrint('🔄 [TOGGLE COMPLETION] Starting database update...');
      await orderService.updateOrder(updatedOrder);
      debugPrint('✅ [TOGGLE COMPLETION] Database update completed');

      // Calculate how much time has passed and ensure minimum sync duration
      final elapsedTime = DateTime.now().difference(syncStartTime);
      final remainingTime = minimumSyncDuration - elapsedTime;

      debugPrint('⏱️ [TOGGLE COMPLETION] Database update took ${elapsedTime.inMilliseconds}ms');
      debugPrint('⏱️ [TOGGLE COMPLETION] Minimum duration: ${minimumSyncDuration.inMilliseconds}ms');
      debugPrint('⏱️ [TOGGLE COMPLETION] Remaining time: ${remainingTime.inMilliseconds}ms');

      if (remainingTime.inMilliseconds > 0) {
        debugPrint('⏳ [TOGGLE COMPLETION] Waiting additional ${remainingTime.inMilliseconds}ms to ensure proper sync');
        try {
          await Future.delayed(remainingTime);
          debugPrint('✅ [TOGGLE COMPLETION] Wait completed successfully');
        } catch (e) {
          debugPrint('❌ [TOGGLE COMPLETION] Wait interrupted: $e');
        }
      } else {
        debugPrint('✅ [TOGGLE COMPLETION] No wait needed - database took longer than minimum');
      }

      // Step 3: Success - Clear syncing state (after minimum duration)
      if (mounted) {
        setState(() {
          final orderIndex = _orders.indexWhere((o) => o.id == order.id);
          if (orderIndex != -1) {
            final currentOrder = _orders[orderIndex];
            final itemIndex = currentOrder.items.indexWhere((i) => i.id == itemId);

            if (itemIndex != -1) {
              final updatedItems = List<OrderItem>.from(currentOrder.items);
              final beforeItem = updatedItems[itemIndex];
              updatedItems[itemIndex] = updatedItems[itemIndex].copyWith(
                isSyncing: false, // Clear syncing indicator
                syncError: null,  // Clear any errors
              );

              _orders[orderIndex] = currentOrder.copyWith(items: updatedItems);

              // Calculate actual syncing duration from user perspective
              final syncStartTime = _syncStartTimes[itemId];
              if (syncStartTime != null) {
                final actualDuration = DateTime.now().difference(syncStartTime);
                debugPrint('🎯 [TOGGLE COMPLETION] ${beforeItem.menuItemName} isSyncing: ${beforeItem.isSyncing} → FALSE');
                debugPrint('⏱️ [USER SYNC DURATION] Actual UI syncing time: ${actualDuration.inMilliseconds}ms');
                _syncStartTimes.remove(itemId);
              }
            }
          }
        });

        debugPrint('✅ [TOGGLE COMPLETION] Sync completed after ${DateTime.now().difference(syncStartTime).inMilliseconds}ms');
      }

      // Trigger sync check for other devices AFTER the syncing state is cleared
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _updateItemCompletionInList();
          }
        });
      }

    } catch (error) {
      // Step 4: Error - Show error state immediately (don't wait for minimum time)
      debugPrint('❌ [TOGGLE COMPLETION] Database update failed after ${DateTime.now().difference(syncStartTime).inMilliseconds}ms: $error');

      if (mounted) {
        setState(() {
          final orderIndex = _orders.indexWhere((o) => o.id == order.id);
          if (orderIndex != -1) {
            final currentOrder = _orders[orderIndex];
            final itemIndex = currentOrder.items.indexWhere((i) => i.id == itemId);

            if (itemIndex != -1) {
              final updatedItems = List<OrderItem>.from(currentOrder.items);
              updatedItems[itemIndex] = updatedItems[itemIndex].copyWith(
                isSyncing: false, // Clear syncing indicator
                syncError: 'Sync failed - tap to retry', // Show error
              );

              _orders[orderIndex] = currentOrder.copyWith(items: updatedItems);
            }
          }
        });

        // Show user-friendly error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to sync - changes saved locally'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _toggleItemCompletion(order, itemId, item),
            ),
          ),
        );
      }
    }
  }

  /// Handle item completion tap with smart confirmation flow
  void _handleItemCompletionTap(Order order, OrderItem item) {
    // Check if item is currently completed (either in database or local state)
    final isCurrentlyCompleted = item.isCompleted || (_completedItems[order.id]?.contains(item.id) ?? false);

    debugPrint('👆 [TAP HANDLER] ${item.menuItemName} tapped - currently completed: $isCurrentlyCompleted');

    if (isCurrentlyCompleted) {
      // Item is completed, show confirmation dialog for unmarking
      debugPrint('⚠️ [TAP HANDLER] Showing confirmation dialog for unmarking ${item.menuItemName}');
      _showUnmarkConfirmationDialog(order, item);
    } else {
      // Item is not completed, mark as complete directly (fast path)
      debugPrint('⚡ [TAP HANDLER] Direct completion for ${item.menuItemName} - 10s timer will apply');
      _toggleItemCompletion(order, item.id, item);
    }
  }

  /// Build completion button with sync status indicators
  Widget _buildCompletionButton(OrderItem item) {
    // Database state takes precedence, local state only for immediate feedback
    final isCompleted = item.isCompleted;
    final isSyncing = item.isSyncing;
    final hasError = item.syncError != null;

    // Debug log the current state being rendered
    if (isSyncing) {
      debugPrint('🎨 [UI RENDER] ${item.menuItemName} showing as SYNCING (isSyncing: $isSyncing, isCompleted: $isCompleted)');
    }

    // Determine button state
    Color backgroundColor;
    Color textColor;
    IconData iconData;
    String buttonText;

    if (hasError) {
      // Sync error state
      backgroundColor = Colors.red[100]!;
      textColor = Colors.red[700]!;
      iconData = Icons.error_outline;
      buttonText = 'Sync Error';
    } else if (isCompleted && isSyncing) {
      // Syncing state
      backgroundColor = Colors.orange[100]!;
      textColor = Colors.orange[700]!;
      iconData = Icons.sync;
      buttonText = 'Syncing...';
    } else if (isCompleted && !isSyncing) {
      // Completed and synced state
      backgroundColor = Colors.green;
      textColor = Colors.white;
      iconData = Icons.check_circle;
      buttonText = 'Done';
    } else {
      // Not completed state
      backgroundColor = Colors.grey[300]!;
      textColor = Colors.grey[700]!;
      iconData = Icons.circle_outlined;
      buttonText = 'Mark as done';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      constraints: const BoxConstraints(minHeight: 36, minWidth: 80),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSyncing)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(textColor),
              ),
            )
          else
            Icon(
              iconData,
              size: 16,
              color: textColor,
            ),
          const SizedBox(width: 6),
          Text(
            buttonText,
            style: TextStyle(
              fontSize: 13,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Show confirmation dialog when unmarking a completed item
  Future<void> _showUnmarkConfirmationDialog(Order order, OrderItem item) async {
    // Calculate how long ago it was completed
    String timeAgoText = '';
    if (item.completedAt != null) {
      final timeDiff = DateTime.now().difference(item.completedAt!);
      if (timeDiff.inMinutes < 2) {
        timeAgoText = 'just now';
      } else if (timeDiff.inHours < 1) {
        timeAgoText = '${timeDiff.inMinutes} minutes ago';
      } else {
        timeAgoText = '${timeDiff.inHours} hours ago';
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.undo, color: Colors.orange),
            SizedBox(width: 8),
            Text('Mark as not done?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${item.menuItemName}"',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (timeAgoText.isNotEmpty)
              Text('Completed $timeAgoText'),
            const SizedBox(height: 12),
            const Text(
              'This will update all devices and notify your team.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, undo'),
          ),
        ],
      ),
    );

    // If user confirmed, proceed with unmarking
    if (confirmed == true) {
      _toggleItemCompletion(order, item.id, item);
    }
  }

  Future<void> _showCancelOrderDialog(Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('orders_page.cancel_order_title'.tr()),
        content: Text(
          'orders_page.cancel_order_message'.tr(namedArgs: {'orderNumber': order.orderNumber}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('orders_page.no_button'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('orders_page.cancel_order_button'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Update order status to cancelled
        final updatedOrder = order.copyWith(
          status: OrderStatus.cancelled,
          updatedAt: DateTime.now(),
        );

        // 🚀 PERFORMANCE FIX: Optimistic update for order cancellation
        final orderIndex = _orders.indexWhere((o) => o.id == order.id);
        if (orderIndex != -1) {
          setState(() {
            _orders[orderIndex] = updatedOrder;
          });
        }

        final orderService = ref.read(supabaseOrderServiceProvider);
      await orderService.updateOrder(updatedOrder);

        // Debug: Order cancelled with optimistic update - no full reload!

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('orders_page.cancel_order_success'.tr(namedArgs: {'orderNumber': order.orderNumber})),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        // 🔄 Error occurred - revert UI and reload data
        // Debug: Order cancellation failed, reverting optimistic changes...
        await _loadOrders(showLoading: false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('orders_page.cancel_order_error'.tr(namedArgs: {'error': e.toString()})),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// 🆕 Show comprehensive order details dialog
  void _showOrderDetailsDialog(Order order) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: order.status == OrderStatus.delivered
                      ? Colors.green[50]
                      : Colors.red[50],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'orders_page.order_details_title'.tr(),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            order.orderNumber,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusChip(order.status),
                  ],
                ),
              ),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Order Info Section
                      _buildOrderInfoSection(order),
                      const SizedBox(height: 20),

                      // Customer Info Section
                      _buildCustomerInfoSection(order),
                      const SizedBox(height: 20),

                      // Order Items Section
                      _buildOrderItemsSection(order),
                      const SizedBox(height: 20),

                      // Order Notes Section (if exists)
                      if (order.notes != null && order.notes!.isNotEmpty) ...[
                        _buildOrderNotesSection(order),
                        const SizedBox(height: 20),
                      ],

                      // Order Total Section
                      _buildOrderTotalSection(order),
                    ],
                  ),
                ),
              ),

              // Footer with close button
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('orders_page.close_button'.tr()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderInfoSection(Order order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'orders_page.order_information'.tr(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              _buildInfoRow(Icons.access_time, 'orders_page.order_time'.tr(), _formatDateTime(order.createdAt)),
              const SizedBox(height: 8),
              if (order.tableNumber != null)
                _buildInfoRow(Icons.table_restaurant, 'orders_page.table_number'.tr(), order.tableNumber!),
              if (order.platform.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildInfoRow(Icons.delivery_dining, 'orders_page.platform'.tr(), order.platform),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerInfoSection(Order order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'orders_page.customer_information'.tr(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            children: [
              _buildInfoRow(Icons.person, 'orders_page.customer_name'.tr(), order.customer.name.isEmpty ? 'orders_page.unknown_customer'.tr() : order.customer.name),
              if (order.customer.phone?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                _buildInfoRow(Icons.phone, 'orders_page.phone_number'.tr(), order.customer.phone!),
              ],
              if (order.customer.email?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                _buildInfoRow(Icons.email, 'orders_page.email'.tr(), order.customer.email!),
              ],
              if (order.customer.address?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                _buildInfoRow(Icons.location_on, 'orders_page.address'.tr(), order.customer.address!),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItemsSection(Order order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'orders_page.order_items'.tr(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...order.items.map((item) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.menuItemName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    'x${item.quantity}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ),
              if (item.selectedOptions.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...item.selectedOptions.map((option) => Padding(
                  padding: const EdgeInsets.only(left: 16, top: 2),
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          option.optionName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      if (option.price > 0)
                        Text(
                          '+${option.price.toStringAsFixed(0)}đ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                )),
              ],
              if (item.notes != null && item.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.edit_note, size: 14, color: Colors.amber[800]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.notes!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[800],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'orders_page.base_price'.tr(namedArgs: {'price': item.basePrice.toStringAsFixed(0)}),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    '${item.subtotal.toStringAsFixed(0)}đ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildOrderNotesSection(Order order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'orders_page.order_notes'.tr(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber[200]!),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.note_alt_outlined, color: Colors.amber[800]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  order.notes!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderTotalSection(Order order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'orders_page.order_total'.tr(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'orders_page.subtotal'.tr(),
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    '${order.subtotal.toStringAsFixed(0)}đ',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              if (order.discount > 0) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'orders_page.discount'.tr(),
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      '-${order.discount.toStringAsFixed(0)}đ',
                      style: const TextStyle(fontSize: 14, color: Colors.red),
                    ),
                  ],
                ),
              ],
              if (order.tax > 0) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'orders_page.tax'.tr(),
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      '${order.tax.toStringAsFixed(0)}đ',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ],
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'orders_page.total'.tr(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${order.total.toStringAsFixed(0)}đ',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
