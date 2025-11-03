import '../core/utils/parse_utils.dart';
import 'order.dart'; // Import for PaymentStatus
import 'payment_method.dart'; // Import for PaymentMethodType

/// Enum for different transaction types
enum TransactionType {
  revenue('REVENUE'),
  expense('EXPENSE'),
  adjustment('ADJUSTMENT'),
  transfer('TRANSFER'),
  fee('FEE');

  const TransactionType(this.value);
  final String value;

  static TransactionType fromString(String value) {
    return TransactionType.values.firstWhere(
      (type) => type.value.toLowerCase() == value.toLowerCase(),
      orElse: () => TransactionType.revenue,
    );
  }

  String get displayName {
    switch (this) {
      case TransactionType.revenue:
        return 'Revenue';
      case TransactionType.expense:
        return 'Expense';
      case TransactionType.adjustment:
        return 'Adjustment';
      case TransactionType.transfer:
        return 'Transfer';
      case TransactionType.fee:
        return 'Fee';
    }
  }

  String get icon {
    switch (this) {
      case TransactionType.revenue:
        return '💰';
      case TransactionType.expense:
        return '💸';
      case TransactionType.adjustment:
        return '⚖️';
      case TransactionType.transfer:
        return '🔄';
      case TransactionType.fee:
        return '📋';
    }
  }
}

/// Enum for reference types
enum ReferenceType {
  order('ORDER'),
  supplier('SUPPLIER'),
  employee('EMPLOYEE'),
  customer('CUSTOMER'),
  system('SYSTEM'),
  manual('MANUAL');

  const ReferenceType(this.value);
  final String value;

  static ReferenceType fromString(String value) {
    return ReferenceType.values.firstWhere(
      (type) => type.value.toLowerCase() == value.toLowerCase(),
      orElse: () => ReferenceType.manual,
    );
  }
}

/// Generalized transaction model for all financial operations
class Transaction {
  final String id;
  final TransactionType transactionType;
  final ReferenceType? referenceType;
  final String? referenceId;
  final PaymentMethodType paymentMethod;
  final PaymentStatus paymentStatus;
  final double amount;
  final String currency;
  final String? transactionId;
  final String? batchId;
  final String? category;
  final String? subcategory;
  final String? description;
  final String? notes;
  final String? accountFrom;
  final String? accountTo;
  final DateTime transactionTime;
  final DateTime createdAt;
  final DateTime updatedAt;

  Transaction({
    required this.id,
    required this.transactionType,
    this.referenceType,
    this.referenceId,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.amount,
    this.currency = 'VND',
    this.transactionId,
    this.batchId,
    this.category,
    this.subcategory,
    this.description,
    this.notes,
    this.accountFrom,
    this.accountTo,
    required this.transactionTime,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: stringFromDynamic(map['id']),
      transactionType: TransactionType.fromString(stringFromDynamic(map['transaction_type'])),
      referenceType: map['reference_type'] != null
          ? ReferenceType.fromString(stringFromDynamic(map['reference_type']))
          : null,
      referenceId: map['reference_id'] != null ? stringFromDynamic(map['reference_id']) : null,
      paymentMethod: PaymentMethodType.fromString(stringFromDynamic(map['payment_method'])),
      paymentStatus: _mapStringToPaymentStatus(stringFromDynamic(map['payment_status'])),
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      currency: stringFromDynamic(map['currency']) == '' ? 'VND' : stringFromDynamic(map['currency']),
      transactionId: map['transaction_id'] != null ? stringFromDynamic(map['transaction_id']) : null,
      batchId: map['batch_id'] != null ? stringFromDynamic(map['batch_id']) : null,
      category: map['category'] != null ? stringFromDynamic(map['category']) : null,
      subcategory: map['subcategory'] != null ? stringFromDynamic(map['subcategory']) : null,
      description: map['description'] != null ? stringFromDynamic(map['description']) : null,
      notes: map['notes'] != null ? stringFromDynamic(map['notes']) : null,
      accountFrom: map['account_from'] != null ? stringFromDynamic(map['account_from']) : null,
      accountTo: map['account_to'] != null ? stringFromDynamic(map['account_to']) : null,
      transactionTime: _parseDateTimeFromDynamic(map['transaction_time']),
      createdAt: _parseDateTimeFromDynamic(map['created_at']),
      updatedAt: _parseDateTimeFromDynamic(map['updated_at']),
    );
  }

  /// Helper method to map string to PaymentStatus
  static PaymentStatus _mapStringToPaymentStatus(String value) {
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

  /// Helper method to parse DateTime from various data types
  static DateTime _parseDateTimeFromDynamic(dynamic value) {
    if (value == null) return DateTime.now();

    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'transaction_type': transactionType.value,
      'reference_type': referenceType?.value,
      'reference_id': referenceId,
      'payment_method': paymentMethod.value,
      'payment_status': paymentStatus.value,
      'amount': amount,
      'currency': currency,
      'transaction_id': transactionId,
      'batch_id': batchId,
      'category': category,
      'subcategory': subcategory,
      'description': description,
      'notes': notes,
      'account_from': accountFrom,
      'account_to': accountTo,
      'transaction_time': transactionTime.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };

    // Only include id if it's not empty (for updates)
    if (id.isNotEmpty) {
      map['id'] = id;
    }

    return map;
  }

  Transaction copyWith({
    String? id,
    TransactionType? transactionType,
    ReferenceType? referenceType,
    String? referenceId,
    PaymentMethodType? paymentMethod,
    PaymentStatus? paymentStatus,
    double? amount,
    String? currency,
    String? transactionId,
    String? batchId,
    String? category,
    String? subcategory,
    String? description,
    String? notes,
    String? accountFrom,
    String? accountTo,
    DateTime? transactionTime,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      transactionType: transactionType ?? this.transactionType,
      referenceType: referenceType ?? this.referenceType,
      referenceId: referenceId ?? this.referenceId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      transactionId: transactionId ?? this.transactionId,
      batchId: batchId ?? this.batchId,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      accountFrom: accountFrom ?? this.accountFrom,
      accountTo: accountTo ?? this.accountTo,
      transactionTime: transactionTime ?? this.transactionTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if transaction is income (positive amount)
  bool get isIncome => amount >= 0;

  /// Check if transaction is expense (negative amount)
  bool get isExpense => amount < 0;

  /// Check if transaction is complete
  bool get isComplete => paymentStatus == PaymentStatus.paid;

  /// Check if transaction is pending
  bool get isPending => paymentStatus == PaymentStatus.pending;

  /// Get absolute amount (always positive)
  double get absoluteAmount => amount.abs();

  /// Convert to PaymentInfo for backward compatibility
  PaymentInfo toPaymentInfo() {
    if (transactionType != TransactionType.revenue || referenceType != ReferenceType.order) {
      throw Exception('Can only convert revenue/order transactions to PaymentInfo');
    }

    return PaymentInfo(
      id: id,
      orderId: referenceId ?? '',
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      amountPaid: amount,
      totalAmount: amount, // Simplified for compatibility
      transactionId: transactionId,
      notes: notes,
      paymentTime: transactionTime,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Transaction &&
        other.id == id &&
        other.transactionType == transactionType &&
        other.referenceType == referenceType &&
        other.referenceId == referenceId &&
        other.paymentMethod == paymentMethod &&
        other.paymentStatus == paymentStatus &&
        other.amount == amount &&
        other.currency == currency;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        transactionType.hashCode ^
        referenceType.hashCode ^
        referenceId.hashCode ^
        paymentMethod.hashCode ^
        paymentStatus.hashCode ^
        amount.hashCode ^
        currency.hashCode;
  }

  @override
  String toString() {
    return 'Transaction(id: $id, type: $transactionType, amount: $amount, method: $paymentMethod, status: $paymentStatus)';
  }
}