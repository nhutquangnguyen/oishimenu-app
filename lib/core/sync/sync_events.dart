// ========================================
// HYBRID SYNC EVENT SYSTEM
// ========================================
// This file defines all event types and models for the hybrid sync system

/// Enum defining all possible sync event types
enum SyncEventType {
  // General sync events
  syncStarted,
  syncCompleted,
  dataUpdated,

  // Order-related events
  orderCreated,
  orderUpdated,
  orderDeleted,
  orderStatusUpdated,
  orderStatusConfirmed,

  // Order item-related events
  itemCompletionToggled,
  itemCompletionConfirmed,
  itemQuantityUpdated,

  // Error and status events
  error,
  networkError,
  syncConflict,

  // Connection events
  connectionRestored,
  connectionLost,
}

/// Main sync event class that carries all synchronization information
class SyncEvent {
  final SyncEventType type;
  final dynamic data;
  final dynamic previousData;
  final String message;
  final DateTime timestamp;
  final String? errorCode;
  final Map<String, dynamic>? metadata;

  SyncEvent({
    required this.type,
    this.data,
    this.previousData,
    required this.message,
    this.errorCode,
    this.metadata,
  }) : timestamp = DateTime.now();

  /// Create a sync started event
  factory SyncEvent.syncStarted(String message, {Map<String, dynamic>? metadata}) {
    return SyncEvent(
      type: SyncEventType.syncStarted,
      message: message,
      metadata: metadata,
    );
  }

  /// Create a data updated event
  factory SyncEvent.dataUpdated(dynamic data, String message) {
    return SyncEvent(
      type: SyncEventType.dataUpdated,
      data: data,
      message: message,
    );
  }

  /// Create an order created event
  factory SyncEvent.orderCreated(dynamic order, {bool isOptimistic = false}) {
    return SyncEvent(
      type: SyncEventType.orderCreated,
      data: order,
      message: isOptimistic ? 'Order created locally' : 'Order created and synced',
      metadata: {'isOptimistic': isOptimistic},
    );
  }

  /// Create an order updated event
  factory SyncEvent.orderUpdated(dynamic newOrder, dynamic oldOrder) {
    return SyncEvent(
      type: SyncEventType.orderUpdated,
      data: newOrder,
      previousData: oldOrder,
      message: 'Order updated',
    );
  }

  /// Create an item completion event
  factory SyncEvent.itemCompletionToggled({
    required String orderId,
    required String itemId,
    required bool isCompleted,
    bool isOptimistic = true,
  }) {
    return SyncEvent(
      type: SyncEventType.itemCompletionToggled,
      data: {
        'orderId': orderId,
        'itemId': itemId,
        'isCompleted': isCompleted,
        'isLocalPending': isOptimistic,
      },
      message: isOptimistic
          ? 'Item completion updated locally'
          : 'Item completion synced',
      metadata: {'isOptimistic': isOptimistic},
    );
  }

  /// Create an item completion confirmed event
  factory SyncEvent.itemCompletionConfirmed({
    required String orderId,
    required String itemId,
    required bool isCompleted,
  }) {
    return SyncEvent(
      type: SyncEventType.itemCompletionConfirmed,
      data: {
        'orderId': orderId,
        'itemId': itemId,
        'isCompleted': isCompleted,
      },
      message: 'Item completion confirmed on server',
    );
  }

  /// Create an order status updated event
  factory SyncEvent.orderStatusUpdated({
    required String orderId,
    required String status,
    bool isOptimistic = true,
  }) {
    return SyncEvent(
      type: SyncEventType.orderStatusUpdated,
      data: {
        'orderId': orderId,
        'status': status,
        'isLocalPending': isOptimistic,
      },
      message: isOptimistic
          ? 'Order status updated locally'
          : 'Order status synced',
      metadata: {'isOptimistic': isOptimistic},
    );
  }

  /// Create an error event
  factory SyncEvent.error({
    required String message,
    String? errorCode,
    dynamic data,
    Exception? exception,
  }) {
    return SyncEvent(
      type: SyncEventType.error,
      message: message,
      errorCode: errorCode,
      data: data,
      metadata: exception != null ? {'exception': exception.toString()} : null,
    );
  }

  /// Create a network error event
  factory SyncEvent.networkError(String message, {dynamic data}) {
    return SyncEvent(
      type: SyncEventType.networkError,
      message: message,
      errorCode: 'NETWORK_ERROR',
      data: data,
    );
  }

  /// Create a sync conflict event
  factory SyncEvent.syncConflict({
    required String message,
    required dynamic localData,
    required dynamic serverData,
  }) {
    return SyncEvent(
      type: SyncEventType.syncConflict,
      message: message,
      data: serverData,
      previousData: localData,
      errorCode: 'SYNC_CONFLICT',
    );
  }

  /// Check if this is an error event
  bool get isError => [
    SyncEventType.error,
    SyncEventType.networkError,
    SyncEventType.syncConflict,
  ].contains(type);

  /// Check if this is an optimistic update
  bool get isOptimistic => metadata?['isOptimistic'] == true;

  /// Get a user-friendly description of the event
  String get description {
    switch (type) {
      case SyncEventType.syncStarted:
        return 'Synchronization started';
      case SyncEventType.syncCompleted:
        return 'Synchronization completed';
      case SyncEventType.dataUpdated:
        return 'Data synchronized from server';
      case SyncEventType.orderCreated:
        return isOptimistic ? 'Order created (saving...)' : 'Order created successfully';
      case SyncEventType.orderUpdated:
        return 'Order information updated';
      case SyncEventType.orderStatusUpdated:
        return isOptimistic ? 'Order status changed (saving...)' : 'Order status updated';
      case SyncEventType.itemCompletionToggled:
        final isCompleted = data?['isCompleted'] ?? false;
        final status = isCompleted ? 'completed' : 'pending';
        return isOptimistic ? 'Item marked as $status (saving...)' : 'Item $status';
      case SyncEventType.itemCompletionConfirmed:
        return 'Item status saved successfully';
      case SyncEventType.error:
        return 'Sync error: $message';
      case SyncEventType.networkError:
        return 'Network error: $message';
      case SyncEventType.syncConflict:
        return 'Sync conflict: $message';
      case SyncEventType.connectionRestored:
        return 'Connection restored';
      case SyncEventType.connectionLost:
        return 'Connection lost';
      default:
        return message;
    }
  }

  /// Convert event to a loggable map
  Map<String, dynamic> toLogMap() {
    return {
      'type': type.toString(),
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'hasData': data != null,
      'hasPreviousData': previousData != null,
      'errorCode': errorCode,
      'metadata': metadata,
      'isError': isError,
      'isOptimistic': isOptimistic,
    };
  }

  @override
  String toString() {
    return 'SyncEvent(type: $type, message: $message, timestamp: $timestamp)';
  }
}

/// Sync metadata class for tracking sync state
class SyncMetadata {
  final DateTime lastUpdated;
  final int version;
  final String key;

  SyncMetadata({
    required this.lastUpdated,
    required this.version,
    required this.key,
  });

  factory SyncMetadata.fromJson(Map<String, dynamic> json) {
    return SyncMetadata(
      lastUpdated: DateTime.parse(json['last_updated']),
      version: json['version'] ?? 1,
      key: json['key'] ?? 'unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'last_updated': lastUpdated.toIso8601String(),
      'version': version,
      'key': key,
    };
  }

  @override
  String toString() {
    return 'SyncMetadata(key: $key, version: $version, lastUpdated: $lastUpdated)';
  }
}

/// Batch operation model for efficient sync operations
class BatchOperation {
  final String type;
  final String orderId;
  final String? itemId;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  BatchOperation({
    required this.type,
    required this.orderId,
    this.itemId,
    required this.data,
  }) : timestamp = DateTime.now();

  /// Create item completion batch operation
  factory BatchOperation.itemCompletion({
    required String orderId,
    required String itemId,
    required bool isCompleted,
  }) {
    return BatchOperation(
      type: 'item_completion',
      orderId: orderId,
      itemId: itemId,
      data: {
        'is_completed': isCompleted,
        'completed_at': isCompleted ? DateTime.now().toIso8601String() : null,
      },
    );
  }

  /// Create order status batch operation
  factory BatchOperation.orderStatus({
    required String orderId,
    required String status,
  }) {
    return BatchOperation(
      type: 'order_status',
      orderId: orderId,
      data: {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      },
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'order_id': orderId,
      'item_id': itemId,
      ...data,
    };
  }

  @override
  String toString() {
    return 'BatchOperation(type: $type, orderId: $orderId, itemId: $itemId)';
  }
}