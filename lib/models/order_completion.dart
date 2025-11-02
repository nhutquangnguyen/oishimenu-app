/// Models for order item completion tracking and statistics
class OrderCompletionStats {
  final String orderId;
  final int totalItems;
  final int completedItems;
  final int remainingItems;
  final double completionPercentage;
  final bool isFullyCompleted;

  OrderCompletionStats({
    required this.orderId,
    required this.totalItems,
    required this.completedItems,
    required this.remainingItems,
    required this.completionPercentage,
    required this.isFullyCompleted,
  });

  factory OrderCompletionStats.fromJson(Map<String, dynamic> json) {
    return OrderCompletionStats(
      orderId: json['order_id']?.toString() ?? '',
      totalItems: json['total_items'] ?? 0,
      completedItems: json['completed_items'] ?? 0,
      remainingItems: json['remaining_items'] ?? 0,
      completionPercentage: (json['completion_percentage'] ?? 0).toDouble(),
      isFullyCompleted: json['is_fully_completed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'total_items': totalItems,
      'completed_items': completedItems,
      'remaining_items': remainingItems,
      'completion_percentage': completionPercentage,
      'is_fully_completed': isFullyCompleted,
    };
  }

  /// Calculate completion percentage based on counts
  static double calculatePercentage(int completed, int total) {
    if (total == 0) return 0.0;
    return (completed / total) * 100.0;
  }

  /// Create completion stats from a list of order items
  static OrderCompletionStats fromOrderItems(String orderId, List<dynamic> items) {
    final totalItems = items.length;
    final completedItems = items.where((item) =>
      (item is Map && item['is_completed'] == true) ||
      (item.isCompleted == true)
    ).length;
    final remainingItems = totalItems - completedItems;
    final percentage = calculatePercentage(completedItems, totalItems);
    final isFullyCompleted = totalItems > 0 && completedItems == totalItems;

    return OrderCompletionStats(
      orderId: orderId,
      totalItems: totalItems,
      completedItems: completedItems,
      remainingItems: remainingItems,
      completionPercentage: percentage,
      isFullyCompleted: isFullyCompleted,
    );
  }

  @override
  String toString() {
    return 'OrderCompletionStats(orderId: $orderId, completed: $completedItems/$totalItems, ${completionPercentage.toStringAsFixed(1)}%)';
  }
}

/// Request model for updating item completion status
class ItemCompletionUpdateRequest {
  final String orderId;
  final String itemId;
  final bool isCompleted;
  final String? completedBy;

  ItemCompletionUpdateRequest({
    required this.orderId,
    required this.itemId,
    required this.isCompleted,
    this.completedBy,
  });

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'item_id': itemId,
      'is_completed': isCompleted,
      'completed_by': completedBy,
    };
  }
}

/// Response model for completion update operations
class ItemCompletionUpdateResponse {
  final bool success;
  final String? error;
  final String? itemId;
  final String? orderId;
  final bool? isCompleted;
  final DateTime? completedAt;
  final String? completedBy;

  ItemCompletionUpdateResponse({
    required this.success,
    this.error,
    this.itemId,
    this.orderId,
    this.isCompleted,
    this.completedAt,
    this.completedBy,
  });

  factory ItemCompletionUpdateResponse.fromJson(Map<String, dynamic> json) {
    return ItemCompletionUpdateResponse(
      success: json['success'] ?? false,
      error: json['error'],
      itemId: json['item_id']?.toString(),
      orderId: json['order_id']?.toString(),
      isCompleted: json['is_completed'],
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      completedBy: json['completed_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'error': error,
      'item_id': itemId,
      'order_id': orderId,
      'is_completed': isCompleted,
      'completed_at': completedAt?.toIso8601String(),
      'completed_by': completedBy,
    };
  }
}

/// Model for batch operations
class BatchCompletionOperation {
  final String type;
  final String orderId;
  final String itemId;
  final bool isCompleted;

  BatchCompletionOperation({
    this.type = 'item_completion',
    required this.orderId,
    required this.itemId,
    required this.isCompleted,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'order_id': orderId,
      'item_id': itemId,
      'is_completed': isCompleted,
    };
  }
}

/// Response model for batch operations
class BatchCompletionResponse {
  final int totalOperations;
  final int successCount;
  final int errorCount;
  final double successRate;
  final List<Map<String, dynamic>> errors;

  BatchCompletionResponse({
    required this.totalOperations,
    required this.successCount,
    required this.errorCount,
    required this.successRate,
    required this.errors,
  });

  factory BatchCompletionResponse.fromJson(Map<String, dynamic> json) {
    return BatchCompletionResponse(
      totalOperations: json['total_operations'] ?? 0,
      successCount: json['success_count'] ?? 0,
      errorCount: json['error_count'] ?? 0,
      successRate: (json['success_rate'] ?? 0).toDouble(),
      errors: List<Map<String, dynamic>>.from(json['errors'] ?? []),
    );
  }

  bool get hasErrors => errorCount > 0;
  bool get isFullySuccessful => errorCount == 0 && successCount > 0;
}