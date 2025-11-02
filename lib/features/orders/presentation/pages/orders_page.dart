import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../models/order.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../../core/widgets/main_layout.dart' show activeOrdersCountProvider;
import '../../../pos/presentation/pages/pos_page.dart';

class OrdersPage extends ConsumerStatefulWidget {
  final String? targetOrderNumber;

  const OrdersPage({super.key, this.targetOrderNumber});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;

  List<Order> _orders = [];
  bool _isLoading = true;
  String? _highlightedOrderNumber; // Track which order to highlight
  final Map<String, GlobalKey> _orderKeys = {}; // Keys for each order

  // Timer for periodic refresh
  Timer? _refreshTimer;

  // App lifecycle state tracking for smart refresh
  bool _isAppActive = true;

  // Scroll controllers to preserve scroll position
  final ScrollController _activeOrdersScrollController = ScrollController();
  final ScrollController _historyOrdersScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    _loadOrders();
    _startRefreshTimer();
  }

  @override
  void didUpdateWidget(OrdersPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    print('🔄 didUpdateWidget called');
    print('🔄 Old targetOrderNumber: ${oldWidget.targetOrderNumber}');
    print('🔄 New targetOrderNumber: ${widget.targetOrderNumber}');

    // Check if targetOrderNumber changed (e.g., when navigating back from editing)
    if (widget.targetOrderNumber != oldWidget.targetOrderNumber &&
        widget.targetOrderNumber != null) {
      print('✅ Target order number changed, triggering scroll to: ${widget.targetOrderNumber}');

      // Set highlight for the target order
      setState(() {
        _highlightedOrderNumber = widget.targetOrderNumber;
      });

      // Trigger scroll after a brief delay to ensure the widget is updated
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _scrollToTargetOrder();

          // Remove highlight after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _highlightedOrderNumber = null;
              });
            }
          });
        }
      });
    } else {
      print('❌ No target order change detected');
    }
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

        // 🚀 BADGE SYNC: Refresh badge count to reflect actual database state
        ref.read(activeOrdersCountProvider.notifier).refresh();

        // Auto-scroll to target order if specified
        if (widget.targetOrderNumber != null) {
          // Set highlight for the target order
          setState(() {
            _highlightedOrderNumber = widget.targetOrderNumber;
          });

          _scrollToTargetOrder();

          // Remove highlight after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _highlightedOrderNumber = null;
              });
            }
          });
        }
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

  double _calculateOrderCardHeight(Order order) {
    // Base card structure height
    const cardPadding = 12.0 * 2; // Padding: all(12)
    const cardMargin = 12.0; // Margin: only(bottom: 12)

    // Header section (order number, time, cancel button)
    const headerHeight = 60.0; // Estimated height of the compact header

    // Calculate height of order items section
    double itemsHeight = 0.0;
    for (final item in order.items) {
      // Each item container
      const itemPadding = 6.0 * 2; // vertical: 6
      const itemMargin = 4.0; // bottom: 4
      const baseItemHeight = 20.0; // Main text line + spacing

      double itemContentHeight = baseItemHeight;

      // Add height for options if present
      if (item.selectedOptions.isNotEmpty) {
        itemContentHeight += 14.0; // 2px spacing + ~12px text
      }

      // Add height for notes if present
      if (item.notes != null && item.notes!.isNotEmpty) {
        itemContentHeight += 13.0; // 2px spacing + ~11px text
      }

      itemsHeight += itemPadding + itemMargin + itemContentHeight;
    }

    // Footer section (total and buttons)
    const footerHeight = 40.0; // Estimated height of total and buttons

    return cardPadding + cardMargin + headerHeight + itemsHeight + footerHeight;
  }

  double _calculateCumulativeHeight(int targetIndex) {
    double totalHeight = 0.0;
    const listViewPadding = 16.0; // ListView padding

    // Add ListView top padding
    totalHeight += listViewPadding;

    print('📐 Calculating height for target index: $targetIndex');
    print('📐 Starting with ListView padding: ${listViewPadding}px');

    // Calculate cumulative height of all orders before the target
    for (int i = 0; i < targetIndex; i++) {
      final orderHeight = _calculateOrderCardHeight(_activeOrders[i]);
      totalHeight += orderHeight;
      print('📐 Order $i (${_activeOrders[i].orderNumber}): ${orderHeight}px (total: ${totalHeight}px)');
    }

    print('📐 Final cumulative height: ${totalHeight}px');
    return totalHeight;
  }

  void _scrollToTargetOrder() {
    // Use highlighted order number if available, otherwise use widget parameter
    final targetOrderNumber = _highlightedOrderNumber ?? widget.targetOrderNumber;
    print('🎯 _scrollToTargetOrder called with: $targetOrderNumber');

    if (targetOrderNumber == null) {
      print('❌ targetOrderNumber is null, aborting scroll');
      return;
    }

    // Find the target order in active orders
    final targetIndex = _activeOrders.indexWhere(
      (order) => order.orderNumber == targetOrderNumber
    );

    print('🔍 Found target order at index: $targetIndex (total orders: ${_activeOrders.length})');

    if (targetIndex != -1) {
      print('📍 Current tab index: ${_tabController.index}');

      // Switch to active orders tab (index 0) if not already there
      if (_tabController.index != 0) {
        print('🔄 Switching to active orders tab');
        _tabController.animateTo(0);
      }

      // Use multiple delays to ensure everything is rendered
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _activeOrdersScrollController.hasClients) {
          print('✅ Scroll controller is ready, starting scroll process');

          // Try using ensureVisible for more reliable scrolling
          final keyString = 'order_$targetOrderNumber';
          final targetKey = _orderKeys[keyString];
          final targetContext = targetKey?.currentContext;

          print('🔑 Looking for key: $keyString');
          print('🎯 Target context found: ${targetContext != null}');

          if (targetContext != null && mounted) {
            print('🎪 Using ensureVisible method');

            // Get current scroll position before scrolling
            final currentPosition = _activeOrdersScrollController.offset;
            print('📏 Current scroll position: ${currentPosition}px');

            Scrollable.ensureVisible(
              targetContext,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              alignment: 0.1, // Position near top of viewport (10% from top)
            ).then((_) {
              // Check scroll position after scrolling
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  final newPosition = _activeOrdersScrollController.offset;
                  print('📏 Final scroll position: ${newPosition}px');
                  print('📏 Scroll distance: ${(newPosition - currentPosition).abs()}px');

                  if ((newPosition - currentPosition).abs() < 10) {
                    print('⚠️ WARNING: Minimal scroll movement detected - order might already be visible');
                  } else {
                    print('✅ Scroll completed successfully');
                  }
                }
              });
            });
          } else {
            print('📐 Using fallback dynamic height calculation');

            // Fallback to dynamic height calculation
            final targetPosition = _calculateCumulativeHeight(targetIndex);
            print('📏 Calculated target position: ${targetPosition}px');

            // Add top padding to ensure the card is well within view
            const topPadding = 100.0;
            final scrollPosition = (targetPosition - topPadding).clamp(
              0.0,
              _activeOrdersScrollController.position.maxScrollExtent
            );

            print('📱 Final scroll position: ${scrollPosition}px (max: ${_activeOrdersScrollController.position.maxScrollExtent}px)');

            _activeOrdersScrollController.animateTo(
              scrollPosition,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
            );
          }
        } else {
          print('❌ Scroll controller not ready: mounted=$mounted, hasClients=${_activeOrdersScrollController.hasClients}');
        }
      });
    } else {
      print('❌ Target order not found in active orders list');
    }
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

          // Create or get GlobalKey for this order
          final keyString = 'order_${order.orderNumber}';
          if (!_orderKeys.containsKey(keyString)) {
            _orderKeys[keyString] = GlobalKey();
          }

          return Container(
            key: _orderKeys[keyString],
            child: _buildActiveOrderCard(order, index),
          );
        },
      ),
    );
  }

  Widget _buildActiveOrderCard(Order order, int index) {
    // Check if this order should be highlighted
    final bool isHighlighted = _highlightedOrderNumber == order.orderNumber;

    // Highlight colors take precedence over alternating colors
    final Color cardColor;
    final Color borderColor;

    if (isHighlighted) {
      cardColor = Colors.green[100]!;
      borderColor = Colors.green[400]!;
    } else {
      // Alternate colors for better distinction
      final bool isEven = index % 2 == 0;
      cardColor = isEven ? Colors.blue[50]! : Colors.orange[50]!;
      borderColor = isEven ? Colors.blue[200]! : Colors.orange[200]!;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isHighlighted ? 4 : 2,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor, width: isHighlighted ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Compact header: Two-row layout to prevent overflow
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Order number, time, and cancel button
                Row(
                  children: [
                    // Order number (clickable)
                    InkWell(
                      onTap: () => _navigateToCheckoutWithOrder(order),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          order.orderNumber,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Time
                    Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 2),
                    Text(
                      _formatTime(order.createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    const Spacer(),
                    // Cancel button (smaller)
                    IconButton(
                      onPressed: () => _showCancelOrderDialog(order),
                      icon: Icon(Icons.close, color: Colors.red[400], size: 20),
                      tooltip: 'orders_page.cancel_order_tooltip'.tr(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Row 2: Customer info only (person icon + name + phone)
                Row(
                  children: [
                    Icon(Icons.person, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _formatCustomerInfo(order),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Order notes (compact)
            if (order.notes != null && order.notes!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.amber[200]!, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.note_alt_outlined, size: 12, color: Colors.amber[800]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        order.notes!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Compact order items
            ...order.items.map((item) => _buildCompactOrderItem(item)),

            const SizedBox(height: 8),

            // Total and compact action buttons
            Row(
              children: [
                Text(
                  '${order.total.toStringAsFixed(0)}đ',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const Spacer(),
                // Compact action buttons
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: () => _navigateToOrderDetail(order),
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
                const SizedBox(width: 6),
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: () => _markOrderDone(order),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text('Complete', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactOrderItem(OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[200]!, width: 0.5),
      ),
      child: Row(
        children: [
          // Quantity badge
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blue[600],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '${item.quantity}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Item name and options
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.menuItemName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Options (compact)
                if (item.selectedOptions.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.selectedOptions.map((opt) => opt.optionName).join(', '),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                // Item notes (compact)
                if (item.notes != null && item.notes!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.note, size: 10, color: Colors.amber[600]),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          item.notes!,
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.amber[700],
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Price
          Text(
            '${item.subtotal.toStringAsFixed(0)}đ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.orange[700],
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
            Text('${order.customer.name} • ${order.items.length} món'),
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

  void _navigateToOrderDetail(Order order) {
    // Navigate to POS page for editing with existing order
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PosPage(existingOrder: order),
      ),
    ).then((result) {
      // Handle return from POS editing
      if (result != null) {
        print('🔙 Returned from POS editing with order: $result');

        // Set the target order for highlighting and scrolling
        setState(() {
          _highlightedOrderNumber = result.toString();
        });

        // Reload orders and then scroll to the target
        _loadOrders(showLoading: false).then((_) {
          // Trigger scroll after orders are loaded
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _scrollToTargetOrder();

              // Remove highlight after 3 seconds
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) {
                  setState(() {
                    _highlightedOrderNumber = null;
                  });
                }
              });
            }
          });
        });
      }
    });
  }

  Future<void> _markOrderDone(Order order) async {
    try {
      // Update order status to delivered (completed)
      final completedOrder = order.copyWith(
        status: OrderStatus.delivered,
        paymentStatus: PaymentStatus.paid,
        paymentMethod: PaymentMethod.cash, // Default to cash for completed orders
        updatedAt: DateTime.now(),
      );

      // 🚀 PERFORMANCE FIX: Optimistic update for order completion
      final orderIndex = _orders.indexWhere((o) => o.id == order.id);
      if (orderIndex != -1) {
        setState(() {
          _orders[orderIndex] = completedOrder;
        });
      }

      final orderService = ref.read(supabaseOrderServiceProvider);
      await orderService.updateOrder(completedOrder);

      // 🚀 INSTANT BADGE UPDATE: Decrement active order count immediately
      ref.read(activeOrdersCountProvider.notifier).decrementCount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('orders_page.complete_order_success'.tr(namedArgs: {'orderNumber': order.orderNumber})),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // 🔄 Error occurred - revert UI and reload data
      await _loadOrders(showLoading: false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('orders_page.complete_order_error'.tr(namedArgs: {'error': e.toString()})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToCheckoutWithOrder(Order order) {
    // Navigate to POS page for editing when order ID is clicked
    _navigateToOrderDetail(order);
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

        // 🚀 INSTANT BADGE UPDATE: Decrement active order count immediately
        ref.read(activeOrdersCountProvider.notifier).decrementCount();

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
