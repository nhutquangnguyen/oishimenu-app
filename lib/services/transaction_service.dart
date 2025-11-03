import '../models/transaction.dart';
import '../models/payment_method.dart';
import '../models/order.dart';
import 'supabase_service.dart';

/// Enhanced service for handling all financial transactions
/// Provides both new transaction functionality and backward compatibility
class TransactionService {
  static const String _transactionsTable = 'transactions';
  static const String _orderPaymentsView = 'order_payments_view'; // Backward compatibility

  // ==================== GENERALIZED TRANSACTION METHODS ====================

  /// Create a new transaction (generalized for all types)
  Future<Transaction?> createTransaction({
    required TransactionType transactionType,
    ReferenceType? referenceType,
    String? referenceId,
    required PaymentMethodType paymentMethod,
    required double amount,
    PaymentStatus paymentStatus = PaymentStatus.paid,
    String? currency = 'VND',
    String? transactionId,
    String? batchId,
    String? category,
    String? subcategory,
    String? description,
    String? notes,
    String? accountFrom,
    String? accountTo,
    DateTime? transactionTime,
  }) async {
    try {
      final now = DateTime.now();
      final transaction = Transaction(
        id: '', // Will be set by database
        transactionType: transactionType,
        referenceType: referenceType,
        referenceId: referenceId,
        paymentMethod: paymentMethod,
        paymentStatus: paymentStatus,
        amount: amount,
        currency: currency ?? 'VND',
        transactionId: transactionId,
        batchId: batchId,
        category: category,
        subcategory: subcategory,
        description: description,
        notes: notes,
        accountFrom: accountFrom,
        accountTo: accountTo,
        transactionTime: transactionTime ?? now,
        createdAt: now,
        updatedAt: now,
      );

      final response = await SupabaseService.client
          .from(_transactionsTable)
          .insert(transaction.toMap())
          .select()
          .single();

      return Transaction.fromMap(response);
    } catch (e) {
      print('🔍 DEBUG TransactionService - Error creating transaction: $e');
      return null;
    }
  }

  /// Get transactions by type and filters
  Future<List<Transaction>> getTransactions({
    TransactionType? transactionType,
    ReferenceType? referenceType,
    String? referenceId,
    PaymentMethodType? paymentMethod,
    PaymentStatus? paymentStatus,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      dynamic query = SupabaseService.client.from(_transactionsTable).select();

      // Apply filters
      if (transactionType != null) {
        query = query.eq('transaction_type', transactionType.value);
      }
      if (referenceType != null) {
        query = query.eq('reference_type', referenceType.value);
      }
      if (referenceId != null) {
        query = query.eq('reference_id', referenceId);
      }
      if (paymentMethod != null) {
        query = query.eq('payment_method', paymentMethod.value);
      }
      if (paymentStatus != null) {
        query = query.eq('payment_status', paymentStatus.value);
      }
      if (category != null) {
        query = query.eq('category', category);
      }
      if (startDate != null) {
        query = query.gte('transaction_time', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('transaction_time', endDate.toIso8601String());
      }

      query = query.order('transaction_time', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;
      return response.map<Transaction>((json) => Transaction.fromMap(json)).toList();
    } catch (e) {
      print('🔍 DEBUG TransactionService - Error getting transactions: $e');
      return [];
    }
  }

  /// Update a transaction
  Future<Transaction?> updateTransaction(
    String transactionId, {
    TransactionType? transactionType,
    PaymentMethodType? paymentMethod,
    PaymentStatus? paymentStatus,
    double? amount,
    String? transactionReference,
    String? category,
    String? subcategory,
    String? description,
    String? notes,
    DateTime? transactionTime,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (transactionType != null) updates['transaction_type'] = transactionType.value;
      if (paymentMethod != null) updates['payment_method'] = paymentMethod.value;
      if (paymentStatus != null) updates['payment_status'] = paymentStatus.value;
      if (amount != null) updates['amount'] = amount;
      if (transactionReference != null) updates['transaction_id'] = transactionReference;
      if (category != null) updates['category'] = category;
      if (subcategory != null) updates['subcategory'] = subcategory;
      if (description != null) updates['description'] = description;
      if (notes != null) updates['notes'] = notes;
      if (transactionTime != null) updates['transaction_time'] = transactionTime.toIso8601String();

      final response = await SupabaseService.client
          .from(_transactionsTable)
          .update(updates)
          .eq('id', transactionId)
          .select()
          .single();

      return Transaction.fromMap(response);
    } catch (e) {
      print('🔍 DEBUG TransactionService - Error updating transaction: $e');
      return null;
    }
  }

  /// Delete a transaction
  Future<bool> deleteTransaction(String transactionId) async {
    try {
      await SupabaseService.client
          .from(_transactionsTable)
          .delete()
          .eq('id', transactionId);
      return true;
    } catch (e) {
      print('🔍 DEBUG TransactionService - Error deleting transaction: $e');
      return false;
    }
  }

  // ==================== ORDER-SPECIFIC METHODS (BACKWARD COMPATIBILITY) ====================

  /// Create order payment (backward compatible with PaymentService)
  Future<PaymentInfo?> createOrderPayment({
    required String orderId,
    required PaymentMethodType paymentMethod,
    required double amountPaid,
    required double totalAmount,
    PaymentStatus paymentStatus = PaymentStatus.paid,
    String? transactionId,
    String? notes,
    DateTime? paymentTime,
  }) async {
    // Determine account mapping based on payment method
    String accountFrom;
    switch (paymentMethod) {
      case PaymentMethodType.cash:
        accountFrom = 'customer_cash';
        break;
      case PaymentMethodType.card:
        accountFrom = 'customer_card';
        break;
      case PaymentMethodType.mobilePayment:
        accountFrom = 'customer_mobile';
        break;
      case PaymentMethodType.bankTransfer:
        accountFrom = 'customer_bank';
        break;
      default:
        accountFrom = 'customer_other';
    }

    final transaction = await createTransaction(
      transactionType: TransactionType.revenue,
      referenceType: ReferenceType.order,
      referenceId: orderId,
      paymentMethod: paymentMethod,
      amount: amountPaid,
      paymentStatus: paymentStatus,
      transactionId: transactionId,
      category: 'food_sales',
      subcategory: 'order_payment',
      description: 'Order payment',
      notes: notes ?? 'Payment made via POS',
      accountFrom: accountFrom,
      accountTo: 'revenue_food_sales',
      transactionTime: paymentTime,
    );

    return transaction?.toPaymentInfo();
  }

  /// Get payments for order (backward compatible)
  Future<List<PaymentInfo>> getPaymentsForOrder(String orderId) async {
    try {
      final transactions = await getTransactions(
        transactionType: TransactionType.revenue,
        referenceType: ReferenceType.order,
        referenceId: orderId,
      );

      return transactions.map((t) => t.toPaymentInfo()).toList();
    } catch (e) {
      print('🔍 DEBUG TransactionService - Error getting order payments: $e');
      return [];
    }
  }

  /// Update order payment status based on transaction records
  Future<void> updateOrderPaymentStatus(String orderId) async {
    try {
      // Get all transactions for the order
      final transactions = await getTransactions(
        transactionType: TransactionType.revenue,
        referenceType: ReferenceType.order,
        referenceId: orderId,
      );

      // Get order details to calculate totals
      final orderResponse = await SupabaseService.client
          .from('orders')
          .select('total')
          .eq('id', orderId)
          .single();

      final orderTotal = (orderResponse['total'] as num).toDouble();
      final totalPaid = transactions
          .where((t) => t.paymentStatus == PaymentStatus.paid)
          .fold<double>(0.0, (sum, transaction) => sum + transaction.amount);

      // Determine overall payment status
      PaymentStatus overallStatus;

      if (transactions.isEmpty) {
        overallStatus = PaymentStatus.pending;
      } else if (totalPaid >= orderTotal) {
        overallStatus = PaymentStatus.paid;
      } else if (totalPaid > 0) {
        overallStatus = PaymentStatus.partiallyPaid;
      } else {
        overallStatus = PaymentStatus.pending;
      }

      // Update order payment status
      await SupabaseService.client
          .from('orders')
          .update({
            'payment_status': overallStatus.value,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);
    } catch (e) {
      print('🔍 DEBUG TransactionService - Error updating order payment status: $e');
    }
  }

  // ==================== FINANCE-SPECIFIC METHODS ====================

  /// Create expense transaction
  Future<Transaction?> createExpense({
    required PaymentMethodType paymentMethod,
    required double amount,
    required String category,
    String? subcategory,
    String? description,
    String? notes,
    String? supplierId,
    String? transactionId,
    DateTime? transactionTime,
  }) async {
    return createTransaction(
      transactionType: TransactionType.expense,
      referenceType: supplierId != null ? ReferenceType.supplier : ReferenceType.manual,
      referenceId: supplierId,
      paymentMethod: paymentMethod,
      amount: -amount.abs(), // Expenses are negative
      category: category,
      subcategory: subcategory,
      description: description,
      notes: notes,
      transactionId: transactionId,
      accountFrom: 'expense_$category',
      accountTo: _getAccountToForPaymentMethod(paymentMethod),
      transactionTime: transactionTime,
    );
  }

  /// Create adjustment transaction (refunds, corrections, etc.)
  Future<Transaction?> createAdjustment({
    required PaymentMethodType paymentMethod,
    required double amount,
    required String category,
    String? subcategory,
    String? description,
    String? notes,
    String? referenceId,
    String? transactionId,
    DateTime? transactionTime,
  }) async {
    return createTransaction(
      transactionType: TransactionType.adjustment,
      referenceType: referenceId != null ? ReferenceType.order : ReferenceType.manual,
      referenceId: referenceId,
      paymentMethod: paymentMethod,
      amount: amount, // Can be positive or negative
      category: category,
      subcategory: subcategory,
      description: description,
      notes: notes,
      transactionId: transactionId,
      transactionTime: transactionTime,
    );
  }

  /// Get financial summary for reporting
  Future<Map<String, dynamic>> getFinancialSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final transactions = await getTransactions(
        startDate: startDate,
        endDate: endDate,
      );

      final summary = <String, dynamic>{};

      // Calculate totals by transaction type
      final revenueTransactions = transactions.where((t) => t.transactionType == TransactionType.revenue);
      final expenseTransactions = transactions.where((t) => t.transactionType == TransactionType.expense);

      final totalRevenue = revenueTransactions
          .where((t) => t.paymentStatus == PaymentStatus.paid)
          .fold<double>(0.0, (sum, t) => sum + t.amount);

      final totalExpenses = expenseTransactions
          .where((t) => t.paymentStatus == PaymentStatus.paid)
          .fold<double>(0.0, (sum, t) => sum + t.amount.abs());

      summary['total_revenue'] = totalRevenue;
      summary['total_expenses'] = totalExpenses;
      summary['net_profit'] = totalRevenue - totalExpenses;
      summary['transaction_count'] = transactions.length;

      // Breakdown by payment method
      final methodTotals = <PaymentMethodType, double>{};
      for (final transaction in transactions.where((t) => t.paymentStatus == PaymentStatus.paid)) {
        methodTotals[transaction.paymentMethod] =
            (methodTotals[transaction.paymentMethod] ?? 0) + transaction.amount.abs();
      }

      summary['payment_method_breakdown'] = methodTotals.map(
        (method, amount) => MapEntry(method.displayName, amount),
      );

      // Breakdown by category
      final categoryTotals = <String, double>{};
      for (final transaction in transactions.where((t) => t.paymentStatus == PaymentStatus.paid)) {
        final category = transaction.category ?? 'uncategorized';
        categoryTotals[category] = (categoryTotals[category] ?? 0) + transaction.amount.abs();
      }

      summary['category_breakdown'] = categoryTotals;

      return summary;
    } catch (e) {
      print('🔍 DEBUG TransactionService - Error getting financial summary: $e');
      return {};
    }
  }

  // ==================== HELPER METHODS ====================

  String _getAccountToForPaymentMethod(PaymentMethodType paymentMethod) {
    switch (paymentMethod) {
      case PaymentMethodType.cash:
        return 'cash_register';
      case PaymentMethodType.card:
        return 'bank_account_card';
      case PaymentMethodType.mobilePayment:
        return 'bank_account_mobile';
      case PaymentMethodType.bankTransfer:
        return 'bank_account_transfer';
      default:
        return 'bank_account_other';
    }
  }
}