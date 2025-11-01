import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../models/order.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../../core/widgets/main_layout.dart' show activeOrdersCountProvider;
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
                              Text(
                                order.orderNumber,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[800],
                                  letterSpacing: 0.5,
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
    final isCompleted = item.isCompleted;

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
                      onTap: () async {
                        final orderService = ref.read(supabaseOrderServiceProvider);
                        final currentUser = ref.read(supabaseAuthServiceProvider).currentUser;

                        // Optimistic UI update for instant feedback
                        setState(() {
                          // This will trigger a rebuild, but the real data comes from database
                        });

                        try {
                          final success = await orderService.toggleItemCompletion(
                            orderId: order.id,
                            itemId: item.id,
                            completedBy: currentUser?.id,
                          );

                          if (success) {
                            // Reload orders to get updated completion status from database
                            _loadOrders();
                          } else {
                            // Show error message
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('orders_page.mark_complete_error'.tr()),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          // Log error for debugging
                          debugPrint('Error toggling item completion: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('orders_page.mark_complete_error'.tr()),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isCompleted ? Colors.green : Colors.grey[300],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCompleted ? Icons.check_circle : Icons.circle_outlined,
                              size: 16,
                              color: isCompleted ? Colors.white : Colors.grey[700],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isCompleted ? 'orders_page.mark_complete'.tr() : 'orders_page.mark_complete_action'.tr(),
                              style: TextStyle(
                                fontSize: 13,
                                color: isCompleted ? Colors.white : Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
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
      // Note: When quantity changes, completion status is preserved since it's per item
      // If needed, we could mark as incomplete here using OrderCompletionService

      // Update the item quantity
      final updatedItems = List<OrderItem>.from(order.items);
      final item = updatedItems[itemIndex];
      final newQuantity = item.quantity + 1;
      final itemNewSubtotal = (item.basePrice + item.selectedOptions.fold(0.0, (sum, opt) => sum + opt.price)) * newQuantity;

      updatedItems[itemIndex] = OrderItem(
        id: item.id,
        menuItemId: item.menuItemId,
        menuItemName: item.menuItemName,
        basePrice: item.basePrice,
        quantity: newQuantity,
        selectedOptions: item.selectedOptions,
        subtotal: itemNewSubtotal,
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

            // 🚀 INSTANT BADGE UPDATE: Decrement active order count immediately
            ref.read(activeOrdersCountProvider.notifier).decrementCount();
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
