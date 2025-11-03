import '../models/payment_method.dart';
import '../models/order.dart';
import 'transaction_service.dart';

/// Helper service to manage payment methods for orders using the new payment system
class OrderPaymentHelper {
  static final TransactionService _transactionService = TransactionService();

  /// Get the primary payment method for an order
  /// Returns the payment method of the largest successful payment
  static Future<PaymentMethodType?> getPrimaryPaymentMethod(String orderId) async {
    try {
      print('🔍 DEBUG Helper - Getting payments for order: $orderId');
      final payments = await _transactionService.getPaymentsForOrder(orderId);
      print('🔍 DEBUG Helper - Found ${payments.length} payments');

      if (payments.isEmpty) {
        print('🔍 DEBUG Helper - No payments found');
        return null;
      }

      // Find the largest successful payment
      final largestPayment = payments
          .where((p) => p.paymentStatus == PaymentStatus.paid)
          .fold<PaymentInfo?>(null, (largest, current) =>
              largest == null || current.amountPaid > largest.amountPaid ? current : largest);

      print('🔍 DEBUG Helper - Largest payment: ${largestPayment?.paymentMethod}');
      return largestPayment?.paymentMethod;
    } catch (e) {
      print('🔍 DEBUG Helper - Error: $e');
      return null;
    }
  }

  /// Get all payment methods used for an order
  static Future<List<PaymentMethodType>> getAllPaymentMethods(String orderId) async {
    try {
      final payments = await _transactionService.getPaymentsForOrder(orderId);
      return payments
          .where((p) => p.paymentStatus == PaymentStatus.paid)
          .map((p) => p.paymentMethod)
          .toSet() // Remove duplicates
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get display name for payment method (for UI)
  static String getPaymentMethodDisplayName(PaymentMethodType? method) {
    if (method == null) return 'No Payment';
    return method.displayName;
  }

  /// Get icon for payment method (for UI)
  static String getPaymentMethodIcon(PaymentMethodType? method) {
    if (method == null) return '❓';
    return method.icon;
  }

  /// Check if an order has any payments
  static Future<bool> hasPayments(String orderId) async {
    try {
      final payments = await _transactionService.getPaymentsForOrder(orderId);
      return payments.any((p) => p.paymentStatus == PaymentStatus.paid);
    } catch (e) {
      return false;
    }
  }

  /// Get total amount paid for an order
  static Future<double> getTotalPaid(String orderId) async {
    try {
      final payments = await _transactionService.getPaymentsForOrder(orderId);
      return payments
          .where((p) => p.paymentStatus == PaymentStatus.paid)
          .fold<double>(0.0, (sum, payment) => sum + payment.amountPaid);
    } catch (e) {
      return 0.0;
    }
  }
}