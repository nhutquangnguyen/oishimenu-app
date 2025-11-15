// ========================================
// HYBRID SYNC MANAGER
// ========================================
// This file implements the hybrid real-time synchronization system
// combining instant local updates with periodic server polling

import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:connectivity_plus/connectivity_plus.dart'; // TODO: Add connectivity monitoring

import 'sync_events.dart';
import '../../models/order.dart';
// import '../../models/customer.dart' as customer_model; // Not needed, using Customer from order.dart
import '../../services/supabase_service.dart';

/// Main hybrid synchronization manager
/// Combines instant local updates with periodic server polling for reliable sync
class HybridSyncManager {
  // Singleton instance
  static final HybridSyncManager _instance = HybridSyncManager._internal();
  factory HybridSyncManager() => _instance;
  HybridSyncManager._internal();

  // ========== CONFIGURATION ==========
  static const Duration _defaultPollInterval = Duration(seconds: 5);
  static const Duration _reconnectPollInterval = Duration(seconds: 3);
  static const Duration _backgroundPollInterval = Duration(seconds: 30);
  static const String _prefKey = 'hybrid_sync_last_update';
  static const String _prefVersionKey = 'hybrid_sync_last_version';
  static const String _syncKey = 'orders_last_updated';

  // ========== STATE MANAGEMENT ==========
  Timer? _pollTimer;
  DateTime? _lastKnownUpdate;
  int? _lastKnownVersion;
  bool _isPolling = false;
  bool _isSyncing = false;
  bool _isInitialized = false;
  bool _isConnected = true;
  bool _isAppInForeground = true;

  // ========== SERVICES ==========
  late SupabaseOrderService _orderService;
  late SharedPreferences _prefs;

  // ========== EVENT STREAMS ==========
  final StreamController<SyncEvent> _syncEventController =
      StreamController<SyncEvent>.broadcast();

  /// Stream of sync events for UI to listen to
  Stream<SyncEvent> get syncEvents => _syncEventController.stream;

  /// Check if manager is initialized
  bool get isInitialized => _isInitialized;

  /// Check if currently syncing
  bool get isSyncing => _isSyncing;

  /// Check if polling is active
  bool get isPolling => _isPolling;

  // ========== INITIALIZATION ==========

  /// Initialize the sync manager
  /// Must be called before using any other methods
  Future<void> initialize() async {
    if (_isInitialized) {
      developer.log('HybridSyncManager already initialized');
      return;
    }

    try {
      // Initialize services
      _orderService = SupabaseOrderService();
      _prefs = await SharedPreferences.getInstance();

      // Load last known sync state
      await _loadSyncState();

      // Start polling
      startPolling();

      _isInitialized = true;
      developer.log('HybridSyncManager initialized successfully');

      _emitSyncEvent(SyncEvent.syncStarted(
        'Hybrid sync manager initialized',
        metadata: {
          'lastUpdate': _lastKnownUpdate?.toIso8601String(),
          'version': _lastKnownVersion,
        },
      ));

    } catch (e, stackTrace) {
      developer.log('Failed to initialize HybridSyncManager',
          error: e, stackTrace: stackTrace);
      _emitSyncEvent(SyncEvent.error(
        message: 'Failed to initialize sync manager: $e',
        exception: e is Exception ? e : Exception(e.toString()),
      ));
      rethrow;
    }
  }

  /// Load sync state from persistent storage
  Future<void> _loadSyncState() async {
    final lastUpdateStr = _prefs.getString(_prefKey);
    final lastVersion = _prefs.getInt(_prefVersionKey);

    if (lastUpdateStr != null) {
      try {
        _lastKnownUpdate = DateTime.parse(lastUpdateStr);
        _lastKnownVersion = lastVersion ?? 1;
        developer.log('Loaded sync state: $_lastKnownUpdate (v$_lastKnownVersion)');
      } catch (e) {
        developer.log('Failed to parse stored sync state: $e');
        await _clearSyncState();
      }
    }
  }

  /// Save sync state to persistent storage
  Future<void> _saveSyncState(SyncMetadata metadata) async {
    try {
      await _prefs.setString(_prefKey, metadata.lastUpdated.toIso8601String());
      await _prefs.setInt(_prefVersionKey, metadata.version);

      _lastKnownUpdate = metadata.lastUpdated;
      _lastKnownVersion = metadata.version;

      developer.log('Saved sync state: ${metadata.lastUpdated} (v${metadata.version})');
    } catch (e) {
      developer.log('Failed to save sync state: $e');
    }
  }

  /// Clear sync state (forces full resync)
  Future<void> _clearSyncState() async {
    await _prefs.remove(_prefKey);
    await _prefs.remove(_prefVersionKey);
    _lastKnownUpdate = null;
    _lastKnownVersion = null;
    developer.log('Cleared sync state');
  }

  // ========== CONNECTIVITY MONITORING ==========
  // TODO: Add connectivity monitoring using connectivity_plus package

  // ========== POLLING MANAGEMENT ==========

  /// Start periodic polling
  void startPolling() {
    if (_isPolling || !_isInitialized) {
      return;
    }

    _isPolling = true;
    _scheduleNextPoll();

    developer.log('Started polling with ${_getCurrentPollInterval().inSeconds}s interval');
  }

  /// Stop polling
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isPolling = false;
    developer.log('Stopped polling');
  }

  /// Schedule the next poll cycle
  void _scheduleNextPoll() {
    _pollTimer?.cancel();

    if (!_isPolling) return;

    final interval = _getCurrentPollInterval();
    _pollTimer = Timer(interval, () {
      _checkForUpdates().then((_) {
        // Schedule next poll if still polling
        if (_isPolling) {
          _scheduleNextPoll();
        }
      });
    });
  }

  /// Get current poll interval based on app state and connectivity
  Duration _getCurrentPollInterval() {
    if (!_isConnected) {
      return _reconnectPollInterval;
    }

    if (!_isAppInForeground) {
      return _backgroundPollInterval;
    }

    return _defaultPollInterval;
  }

  /// Set app foreground state (call from app lifecycle events)
  void setAppForegroundState(bool isInForeground) {
    if (_isAppInForeground != isInForeground) {
      _isAppInForeground = isInForeground;
      developer.log('App foreground state changed: $isInForeground');

      if (isInForeground && _isPolling) {
        // Returning to foreground - immediate sync and faster polling
        forceRefresh();
      }

      // Polling will adjust interval on next cycle
    }
  }

  // ========== SYNC OPERATIONS ==========

  /// Check for server updates and sync if needed
  Future<bool> _checkForUpdates() async {
    if (_isSyncing || !_isConnected) {
      return false;
    }

    try {
      _isSyncing = true;

      final serverMetadata = await _getServerSyncMetadata();

      if (_shouldSync(serverMetadata)) {
        await _performFullSync(serverMetadata);
        return true;
      }

      return false;

    } catch (e, stackTrace) {
      developer.log('Sync check failed', error: e, stackTrace: stackTrace);

      _emitSyncEvent(SyncEvent.networkError(
        'Failed to check for updates: $e',
        data: {'error': e.toString()},
      ));

      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// Get sync metadata from server
  Future<SyncMetadata> _getServerSyncMetadata() async {
    try {
      final response = await SupabaseService.client
          .rpc('rpc_get_sync_metadata', params: {'sync_key': _syncKey});

      if (response == null || response.isEmpty) {
        throw Exception('No sync metadata returned from server');
      }

      final data = response.first;
      return SyncMetadata.fromJson({
        'last_updated': data['last_updated'],
        'version': data['version'],
        'key': _syncKey,
      });

    } catch (e) {
      developer.log('Failed to get server sync metadata: $e');
      rethrow;
    }
  }

  /// Determine if sync is needed
  bool _shouldSync(SyncMetadata serverMetadata) {
    // First time sync
    if (_lastKnownUpdate == null || _lastKnownVersion == null) {
      developer.log('First time sync needed');
      return true;
    }

    // Version-based sync (primary method)
    if (serverMetadata.version > _lastKnownVersion!) {
      developer.log('Version sync needed: ${serverMetadata.version} > $_lastKnownVersion');
      return true;
    }

    // Timestamp-based sync (fallback)
    if (serverMetadata.lastUpdated.isAfter(_lastKnownUpdate!)) {
      developer.log('Timestamp sync needed: ${serverMetadata.lastUpdated} > $_lastKnownUpdate');
      return true;
    }

    return false;
  }

  /// Perform full data synchronization
  Future<void> _performFullSync(SyncMetadata serverMetadata) async {
    developer.log('Performing full sync to version ${serverMetadata.version}');

    _emitSyncEvent(SyncEvent.syncStarted(
      'Synchronizing data from server...',
      metadata: {
        'serverVersion': serverMetadata.version,
        'localVersion': _lastKnownVersion,
      },
    ));

    try {
      // Fetch fresh data from server
      final freshOrders = await _orderService.getOrders();

      // Update local sync state
      await _saveSyncState(serverMetadata);

      // Notify listeners of updated data
      _emitSyncEvent(SyncEvent.dataUpdated(
        freshOrders,
        'Data synchronized successfully (${freshOrders.length} orders)',
      ));

      developer.log('Sync completed successfully. Local version: $_lastKnownVersion');

    } catch (e, stackTrace) {
      developer.log('Full sync failed', error: e, stackTrace: stackTrace);

      _emitSyncEvent(SyncEvent.error(
        message: 'Sync failed: $e',
        exception: e is Exception ? e : Exception(e.toString()),
      ));

      rethrow;
    }
  }

  /// Force immediate refresh (bypasses polling timer)
  Future<void> forceRefresh() async {
    developer.log('Force refresh requested');

    // Clear local state to force sync
    final oldUpdate = _lastKnownUpdate;
    final oldVersion = _lastKnownVersion;

    _lastKnownUpdate = null;
    _lastKnownVersion = null;

    try {
      final hadUpdates = await _checkForUpdates();

      if (!hadUpdates) {
        // Restore old state if no updates
        _lastKnownUpdate = oldUpdate;
        _lastKnownVersion = oldVersion;

        _emitSyncEvent(SyncEvent(
          type: SyncEventType.syncCompleted,
          message: 'No updates available',
        ));
      }
    } catch (e) {
      // Restore old state on error
      _lastKnownUpdate = oldUpdate;
      _lastKnownVersion = oldVersion;
      rethrow;
    }
  }

  // ========== USER ACTION METHODS ==========

  /// Create order with instant local feedback
  Future<Order> createOrder({
    required String customerId,
    required List<OrderItem> items,
    String? notes,
    OrderType orderType = OrderType.dineIn,
    String? tableNumber,
  }) async {
    // Create customer for Order model (using the Customer class from order.dart)
    final orderCustomer = Customer(
      id: customerId,
      name: 'Loading...',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Generate optimistic order
    final optimisticOrder = Order(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      orderNumber: 'TEMP-${DateTime.now().millisecondsSinceEpoch}',
      customer: orderCustomer,
      items: items,
      subtotal: items.fold(0.0, (sum, item) => sum + item.subtotal),
      total: items.fold(0.0, (sum, item) => sum + item.subtotal),
      orderType: orderType,
      status: OrderStatus.pending,
      paymentStatus: PaymentStatus.pending,
      notes: notes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Immediate UI update
    _emitSyncEvent(SyncEvent.orderCreated(optimisticOrder, isOptimistic: true));

    try {
      // Create a full order object for the service
      final fullOrder = optimisticOrder.copyWith(
        customer: orderCustomer,
      );

      // Save to server (returns order ID as String)
      final orderId = await _orderService.createOrder(fullOrder);

      // Fetch the created order from server to get complete data
      final allOrders = await _orderService.getOrders();
      final serverOrder = allOrders.firstWhere(
        (order) => order.id == orderId,
        orElse: () => fullOrder.copyWith(id: orderId),
      );

      // Replace optimistic order with server order
      _emitSyncEvent(SyncEvent.orderUpdated(serverOrder, optimisticOrder));

      // Update sync timestamp
      await _updateLocalSyncTimestamp();

      // Order creation complete - sync events handle communication

      return serverOrder;

    } catch (e, stackTrace) {
      developer.log('Failed to create order', error: e, stackTrace: stackTrace);

      _emitSyncEvent(SyncEvent.error(
        message: 'Failed to create order: $e',
        data: optimisticOrder,
        exception: e is Exception ? e : Exception(e.toString()),
      ));

      rethrow;
    }
  }


  /// Update order status with instant feedback
  Future<void> updateOrderStatus({
    required String orderId,
    required OrderStatus status,
  }) async {
    // Immediate UI update
    _emitSyncEvent(SyncEvent.orderStatusUpdated(
      orderId: orderId,
      status: status.value,
      isOptimistic: true,
    ));

    try {
      // Save to server
      await _orderService.updateOrderStatus(orderId, status);

      // Confirm server save
      _emitSyncEvent(SyncEvent(
        type: SyncEventType.orderStatusConfirmed,
        data: {'orderId': orderId, 'status': status.value},
        message: 'Order status updated successfully',
      ));

      // Update sync timestamp
      await _updateLocalSyncTimestamp();

      // Item completion update complete - sync events handle communication

    } catch (e, stackTrace) {
      developer.log('Failed to update order status',
          error: e, stackTrace: stackTrace);

      _emitSyncEvent(SyncEvent.error(
        message: 'Failed to update order status: $e',
        data: {'orderId': orderId},
        exception: e is Exception ? e : Exception(e.toString()),
      ));

      rethrow;
    }
  }

  // ========== UTILITY METHODS ==========

  /// Update local sync timestamp to current time
  /// Call this after making successful changes to prevent immediate re-sync
  Future<void> _updateLocalSyncTimestamp() async {
    final now = DateTime.now();
    await _prefs.setString(_prefKey, now.toIso8601String());
    _lastKnownUpdate = now;

    // Don't increment version as server will do that
    developer.log('Updated local sync timestamp to $now');
  }

  /// Emit sync event to listeners
  void _emitSyncEvent(SyncEvent event) {
    if (kDebugMode) {
      developer.log('SyncEvent: ${event.type} - ${event.message}');
    }

    if (!_syncEventController.isClosed) {
      _syncEventController.add(event);
    }
  }

  /// Get current sync status
  Map<String, dynamic> getSyncStatus() {
    return {
      'isInitialized': _isInitialized,
      'isPolling': _isPolling,
      'isSyncing': _isSyncing,
      'isConnected': _isConnected,
      'isAppInForeground': _isAppInForeground,
      'lastKnownUpdate': _lastKnownUpdate?.toIso8601String(),
      'lastKnownVersion': _lastKnownVersion,
      'pollInterval': _getCurrentPollInterval().inSeconds,
    };
  }

  // ========== CLEANUP ==========

  /// Dispose of resources
  void dispose() {
    developer.log('Disposing HybridSyncManager');

    stopPolling();

    if (!_syncEventController.isClosed) {
      _syncEventController.close();
    }

    _isInitialized = false;
  }
}