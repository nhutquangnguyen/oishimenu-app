import '../core/utils/parse_utils.dart';
import 'order.dart'; // Import for PaymentStatus

/// Enum for different payment method types
enum PaymentMethodType {
  cash('cash', 'Cash', '💵'),
  card('card', 'Card', '💳'),
  mobilePayment('mobile_payment', 'Mobile Payment', '📱'),
  bankTransfer('bank_transfer', 'Bank Transfer', '🏦'),
  other('other', 'Other', '💰');

  const PaymentMethodType(this.value, this.displayName, this.icon);

  final String value;
  final String displayName;
  final String icon;

  static PaymentMethodType fromString(String value) {
    return PaymentMethodType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => PaymentMethodType.cash,
    );
  }
}

/// Model for payment information
class PaymentInfo {
  final String id;
  final String orderId;
  final PaymentMethodType paymentMethod;
  final PaymentStatus paymentStatus;
  final double amountPaid;
  final double totalAmount;
  final String? transactionId;
  final String? notes;
  final DateTime paymentTime;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentInfo({
    required this.id,
    required this.orderId,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.amountPaid,
    required this.totalAmount,
    this.transactionId,
    this.notes,
    required this.paymentTime,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentInfo.fromMap(Map<String, dynamic> map) {
    return PaymentInfo(
      id: stringFromDynamic(map['id']),
      orderId: stringFromDynamic(map['order_id']),
      paymentMethod: PaymentMethodType.fromString(stringFromDynamic(map['payment_method'])),
      paymentStatus: _mapStringToPaymentStatus(stringFromDynamic(map['payment_status'])),
      amountPaid: (map['amount_paid'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      transactionId: map['transaction_id'] != null ? stringFromDynamic(map['transaction_id']) : null,
      notes: map['notes'] != null ? stringFromDynamic(map['notes']) : null,
      paymentTime: DateTime.fromMillisecondsSinceEpoch(
        map['payment_time'] is int ? map['payment_time'] : DateTime.parse(map['payment_time']).millisecondsSinceEpoch,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] is int ? map['created_at'] : DateTime.parse(map['created_at']).millisecondsSinceEpoch,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        map['updated_at'] is int ? map['updated_at'] : DateTime.parse(map['updated_at']).millisecondsSinceEpoch,
      ),
    );
  }

  /// Helper method to map string to PaymentStatus with proper mapping
  static PaymentStatus _mapStringToPaymentStatus(String value) {
    // Handle the different status value formats between the two enums
    switch (value.toLowerCase()) {
      case 'pending':
        return PaymentStatus.pending;
      case 'completed':
      case 'paid':
        return PaymentStatus.paid;
      case 'failed':
        return PaymentStatus.failed;
      case 'refunded':
        return PaymentStatus.refunded;
      case 'partially_paid':
        return PaymentStatus.partiallyPaid;
      default:
        return PaymentStatus.pending;
    }
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'order_id': orderId,
      'payment_method': paymentMethod.value,
      'payment_status': paymentStatus.value,
      'amount_paid': amountPaid,
      'total_amount': totalAmount,
      'transaction_id': transactionId,
      'notes': notes,
      'payment_time': paymentTime.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };

    // Only include id if it's not empty (for updates)
    if (id.isNotEmpty) {
      map['id'] = id;
    }

    return map;
  }

  PaymentInfo copyWith({
    String? id,
    String? orderId,
    PaymentMethodType? paymentMethod,
    PaymentStatus? paymentStatus,
    double? amountPaid,
    double? totalAmount,
    String? transactionId,
    String? notes,
    DateTime? paymentTime,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentInfo(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      amountPaid: amountPaid ?? this.amountPaid,
      totalAmount: totalAmount ?? this.totalAmount,
      transactionId: transactionId ?? this.transactionId,
      notes: notes ?? this.notes,
      paymentTime: paymentTime ?? this.paymentTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if payment is complete
  bool get isFullyPaid => paymentStatus == PaymentStatus.paid && amountPaid >= totalAmount;

  /// Check if payment is partial
  bool get isPartiallyPaid => paymentStatus == PaymentStatus.partiallyPaid || (amountPaid > 0 && amountPaid < totalAmount);

  /// Get remaining amount to be paid
  double get remainingAmount => totalAmount - amountPaid;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PaymentInfo &&
        other.id == id &&
        other.orderId == orderId &&
        other.paymentMethod == paymentMethod &&
        other.paymentStatus == paymentStatus &&
        other.amountPaid == amountPaid &&
        other.totalAmount == totalAmount &&
        other.transactionId == transactionId &&
        other.notes == notes &&
        other.paymentTime == paymentTime &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        orderId.hashCode ^
        paymentMethod.hashCode ^
        paymentStatus.hashCode ^
        amountPaid.hashCode ^
        totalAmount.hashCode ^
        transactionId.hashCode ^
        notes.hashCode ^
        paymentTime.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }

  @override
  String toString() {
    return 'PaymentInfo(id: $id, orderId: $orderId, paymentMethod: $paymentMethod, paymentStatus: $paymentStatus, amountPaid: $amountPaid, totalAmount: $totalAmount, transactionId: $transactionId, notes: $notes, paymentTime: $paymentTime, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}