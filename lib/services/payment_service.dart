import '../models/payment_method.dart';
import '../models/order.dart';
import 'supabase_service.dart';

class PaymentService {
  static const String _paymentsTable = 'order_payments';

  /// Create a new payment record for an order
  Future<PaymentInfo?> createPayment({
    required String orderId,
    required PaymentMethodType paymentMethod,
    required double amountPaid,
    required double totalAmount,
    PaymentStatus paymentStatus = PaymentStatus.paid,
    String? transactionId,
    String? notes,
    DateTime? paymentTime,
  }) async {
    try {
      final now = DateTime.now();
      final payment = PaymentInfo(
        id: '', // Will be set by database
        orderId: orderId,
        paymentMethod: paymentMethod,
        paymentStatus: paymentStatus,
        amountPaid: amountPaid,
        totalAmount: totalAmount,
        transactionId: transactionId,
        notes: notes,
        paymentTime: paymentTime ?? now,
        createdAt: now,
        updatedAt: now,
      );

      final response = await SupabaseService.client
          .from(_paymentsTable)
          .insert(payment.toMap())
          .select()
          .single();

      return PaymentInfo.fromMap(response);
    } catch (e) {
      // Check if this is a table not found error
      if (e.toString().contains('Could not find the table') ||
          e.toString().contains('PGRST205') ||
          e.toString().contains('order_payments')) {
        // Gracefully handle missing table - payment record will be skipped
        return null;
      }
      throw Exception('Failed to create payment: $e');
    }
  }

  /// Get payment information for a specific order
  Future<List<PaymentInfo>> getPaymentsForOrder(String orderId) async {
    try {
      final response = await SupabaseService.client
          .from(_paymentsTable)
          .select()
          .eq('order_id', orderId)
          .order('created_at', ascending: false);

      return response.map<PaymentInfo>((json) => PaymentInfo.fromMap(json)).toList();
    } catch (e) {
      // Check if this is a table not found error
      if (e.toString().contains('Could not find the table') ||
          e.toString().contains('PGRST205') ||
          e.toString().contains('order_payments')) {
        // Gracefully handle missing table - return empty list
        return [];
      }
      throw Exception('Failed to get payments for order: $e');
    }
  }

  /// Get a specific payment by ID
  Future<PaymentInfo?> getPaymentById(String paymentId) async {
    try {
      final response = await SupabaseService.client
          .from(_paymentsTable)
          .select()
          .eq('id', paymentId)
          .maybeSingle();

      return response != null ? PaymentInfo.fromMap(response) : null;
    } catch (e) {
      // Check if this is a table not found error
      if (e.toString().contains('Could not find the table') ||
          e.toString().contains('PGRST205') ||
          e.toString().contains('order_payments')) {
        // Gracefully handle missing table - return null
        return null;
      }
      throw Exception('Failed to get payment: $e');
    }
  }

  /// Update payment information
  Future<PaymentInfo> updatePayment(String paymentId, {
    PaymentMethodType? paymentMethod,
    PaymentStatus? paymentStatus,
    double? amountPaid,
    String? transactionId,
    String? notes,
    DateTime? paymentTime,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (paymentMethod != null) updates['payment_method'] = paymentMethod.value;
      if (paymentStatus != null) updates['payment_status'] = paymentStatus.value;
      if (amountPaid != null) updates['amount_paid'] = amountPaid;
      if (transactionId != null) updates['transaction_id'] = transactionId;
      if (notes != null) updates['notes'] = notes;
      if (paymentTime != null) updates['payment_time'] = paymentTime.toIso8601String();

      final response = await SupabaseService.client
          .from(_paymentsTable)
          .update(updates)
          .eq('id', paymentId)
          .select()
          .single();

      return PaymentInfo.fromMap(response);
    } catch (e) {
      throw Exception('Failed to update payment: $e');
    }
  }

  /// Delete a payment record
  Future<void> deletePayment(String paymentId) async {
    try {
      await SupabaseService.client
          .from(_paymentsTable)
          .delete()
          .eq('id', paymentId);
    } catch (e) {
      throw Exception('Failed to delete payment: $e');
    }
  }

  /// Update order payment status based on payment records
  Future<void> updateOrderPaymentStatus(String orderId) async {
    try {
      // Get all payments for the order
      final payments = await getPaymentsForOrder(orderId);

      // Get order details to calculate totals
      final orderResponse = await SupabaseService.client
          .from('orders')
          .select('total')
          .eq('id', orderId)
          .single();

      final orderTotal = (orderResponse['total'] as num).toDouble();
      final totalPaid = payments.fold<double>(0.0, (sum, payment) =>
          payment.paymentStatus == PaymentStatus.paid ? sum + payment.amountPaid : sum);

      // Determine overall payment status
      PaymentStatus overallStatus;

      if (payments.isEmpty) {
        overallStatus = PaymentStatus.pending;
      } else if (totalPaid >= orderTotal) {
        overallStatus = PaymentStatus.paid;
      } else if (totalPaid > 0) {
        overallStatus = PaymentStatus.partiallyPaid;
      } else {
        overallStatus = PaymentStatus.pending;
      }

      // Update order payment status (payment_method column removed - now stored in order_payments table)
      await SupabaseService.client
          .from('orders')
          .update({
            'payment_status': overallStatus.value,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);
    } catch (e) {
      // Check if this is a table not found error
      if (e.toString().contains('Could not find the table') ||
          e.toString().contains('PGRST205') ||
          e.toString().contains('order_payments')) {
        // Gracefully handle missing table - skip payment status update
        return;
      }
      throw Exception('Failed to update order payment status: $e');
    }
  }


  /// Convert PaymentMethod to PaymentMethodType
  PaymentMethodType convertToPaymentMethodType(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.none:
        return PaymentMethodType.cash; // Default fallback
      case PaymentMethod.cash:
        return PaymentMethodType.cash;
      case PaymentMethod.card:
        return PaymentMethodType.card;
      case PaymentMethod.mobilePayment:
        return PaymentMethodType.mobilePayment;
      case PaymentMethod.bankTransfer:
        return PaymentMethodType.bankTransfer;
      case PaymentMethod.other:
        return PaymentMethodType.other;
    }
  }

  /// Get payment statistics for reporting
  Future<Map<String, dynamic>> getPaymentStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = SupabaseService.client
          .from(_paymentsTable)
          .select('payment_method, payment_status, amount_paid, created_at');

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query;
      final payments = response.map<PaymentInfo>((json) => PaymentInfo.fromMap(json)).toList();

      // Calculate statistics
      final stats = <String, dynamic>{};
      final methodTotals = <PaymentMethodType, double>{};
      final statusCounts = <PaymentStatus, int>{};
      double totalRevenue = 0.0;

      for (final payment in payments) {
        if (payment.paymentStatus == PaymentStatus.paid) {
          methodTotals[payment.paymentMethod] =
              (methodTotals[payment.paymentMethod] ?? 0) + payment.amountPaid;
          totalRevenue += payment.amountPaid;
        }
        statusCounts[payment.paymentStatus] =
            (statusCounts[payment.paymentStatus] ?? 0) + 1;
      }

      stats['total_revenue'] = totalRevenue;
      stats['payment_method_breakdown'] = methodTotals.map(
        (method, amount) => MapEntry(method.displayName, amount),
      );
      stats['payment_status_counts'] = statusCounts.map(
        (status, count) => MapEntry(status.displayName, count),
      );
      stats['total_transactions'] = payments.length;

      return stats;
    } catch (e) {
      throw Exception('Failed to get payment statistics: $e');
    }
  }
}