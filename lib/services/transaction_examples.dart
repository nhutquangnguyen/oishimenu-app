import 'transaction_service.dart';
import '../models/transaction.dart';
import '../models/payment_method.dart';
import '../models/order.dart';

/// Examples of how to use the new TransactionService
/// This file demonstrates various transaction scenarios for both POS and Finance modules
class TransactionExamples {
  final TransactionService _transactionService = TransactionService();

  // ==================== POS TRANSACTIONS (BACKWARD COMPATIBLE) ====================

  /// Example: Create order payment (exactly like the old PaymentService)
  Future<void> createOrderPaymentExample() async {
    final payment = await _transactionService.createOrderPayment(
      orderId: 'order-123',
      paymentMethod: PaymentMethodType.cash,
      amountPaid: 50000,
      totalAmount: 50000,
      paymentStatus: PaymentStatus.paid,
      notes: 'Cash payment for lunch order',
    );

    print('Order payment created: ${payment?.id}');
  }

  /// Example: Get all payments for an order
  Future<void> getOrderPaymentsExample() async {
    final payments = await _transactionService.getPaymentsForOrder('order-123');
    print('Found ${payments.length} payments for order');

    for (final payment in payments) {
      print('Payment: ${payment.paymentMethod.displayName} - ${payment.amountPaid}');
    }
  }

  // ==================== FINANCE TRANSACTIONS (NEW FUNCTIONALITY) ====================

  /// Example: Record a supplier payment (expense)
  Future<void> createSupplierPaymentExample() async {
    final expense = await _transactionService.createExpense(
      paymentMethod: PaymentMethodType.bankTransfer,
      amount: 2000000, // 2M VND for food supplies
      category: 'food_supplies',
      subcategory: 'vegetables',
      description: 'Weekly vegetable order from Supplier ABC',
      notes: 'Invoice #INV-2024-001',
      supplierId: 'supplier-abc-123',
      transactionTime: DateTime.now(),
    );

    print('Supplier payment recorded: ${expense?.id}');
  }

  /// Example: Record rent payment
  Future<void> createRentPaymentExample() async {
    final expense = await _transactionService.createExpense(
      paymentMethod: PaymentMethodType.bankTransfer,
      amount: 15000000, // 15M VND monthly rent
      category: 'rent',
      subcategory: 'restaurant_space',
      description: 'Monthly rent for restaurant location',
      notes: 'Rent for November 2024',
      transactionTime: DateTime.now(),
    );

    print('Rent payment recorded: ${expense?.id}');
  }

  /// Example: Record employee wages
  Future<void> createWagePaymentExample() async {
    final expense = await _transactionService.createTransaction(
      transactionType: TransactionType.expense,
      referenceType: ReferenceType.employee,
      referenceId: 'employee-456',
      paymentMethod: PaymentMethodType.bankTransfer,
      amount: -8000000, // 8M VND salary (negative for expense)
      category: 'wages',
      subcategory: 'chef_salary',
      description: 'Monthly salary for head chef',
      notes: 'Salary for November 2024',
      accountFrom: 'expense_wages',
      accountTo: 'bank_account_transfer',
    );

    print('Wage payment recorded: ${expense?.id}');
  }

  /// Example: Record a refund (adjustment)
  Future<void> createRefundExample() async {
    final refund = await _transactionService.createAdjustment(
      paymentMethod: PaymentMethodType.cash,
      amount: -25000, // Negative because money is going out
      category: 'refund',
      subcategory: 'order_cancellation',
      description: 'Refund for cancelled order',
      notes: 'Customer cancelled order due to long wait time',
      referenceId: 'order-789', // Original order ID
      transactionTime: DateTime.now(),
    );

    print('Refund recorded: ${refund?.id}');
  }

  /// Example: Record bank fees
  Future<void> createBankFeeExample() async {
    final fee = await _transactionService.createTransaction(
      transactionType: TransactionType.fee,
      referenceType: ReferenceType.system,
      paymentMethod: PaymentMethodType.bankTransfer,
      amount: -50000, // 50k VND bank fee
      category: 'bank_fees',
      subcategory: 'transaction_fee',
      description: 'Monthly bank account maintenance fee',
      notes: 'Auto-deducted by bank',
      accountFrom: 'expense_fees',
      accountTo: 'bank_account_transfer',
    );

    print('Bank fee recorded: ${fee?.id}');
  }

  // ==================== REPORTING EXAMPLES ====================

  /// Example: Get daily financial summary
  Future<void> getDailySummaryExample() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final summary = await _transactionService.getFinancialSummary(
      startDate: startOfDay,
      endDate: endOfDay,
    );

    print('Daily Financial Summary:');
    print('Revenue: ${summary['total_revenue']} VND');
    print('Expenses: ${summary['total_expenses']} VND');
    print('Net Profit: ${summary['net_profit']} VND');
    print('Transactions: ${summary['transaction_count']}');

    // Payment method breakdown
    final methodBreakdown = summary['payment_method_breakdown'] as Map<String, double>;
    print('\nPayment Methods:');
    methodBreakdown.forEach((method, amount) {
      print('  $method: $amount VND');
    });

    // Category breakdown
    final categoryBreakdown = summary['category_breakdown'] as Map<String, double>;
    print('\nCategories:');
    categoryBreakdown.forEach((category, amount) {
      print('  $category: $amount VND');
    });
  }

  /// Example: Get all expenses for the month
  Future<void> getMonthlyExpensesExample() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    final expenses = await _transactionService.getTransactions(
      transactionType: TransactionType.expense,
      startDate: startOfMonth,
      endDate: endOfMonth,
    );

    print('Monthly Expenses (${expenses.length} transactions):');
    double totalExpenses = 0;

    for (final expense in expenses) {
      print('${expense.category}: ${expense.amount.abs()} VND - ${expense.description}');
      totalExpenses += expense.amount.abs();
    }

    print('Total Expenses: $totalExpenses VND');
  }

  /// Example: Get cash transactions for reconciliation
  Future<void> getCashTransactionsExample() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final cashTransactions = await _transactionService.getTransactions(
      paymentMethod: PaymentMethodType.cash,
      paymentStatus: PaymentStatus.paid,
      startDate: startOfDay,
    );

    print('Today\'s Cash Transactions:');
    double totalCashIn = 0;
    double totalCashOut = 0;

    for (final transaction in cashTransactions) {
      if (transaction.amount > 0) {
        totalCashIn += transaction.amount;
        print('IN:  +${transaction.amount} VND - ${transaction.description}');
      } else {
        totalCashOut += transaction.amount.abs();
        print('OUT: -${transaction.amount.abs()} VND - ${transaction.description}');
      }
    }

    print('\nCash Summary:');
    print('Cash In: $totalCashIn VND');
    print('Cash Out: $totalCashOut VND');
    print('Net Cash: ${totalCashIn - totalCashOut} VND');
  }

  // ==================== MIGRATION HELPER ====================

  /// Example: Migrate from old PaymentService to new TransactionService
  Future<void> migrationExample() async {
    // OLD WAY (still works for backward compatibility):
    final oldPayment = await _transactionService.createOrderPayment(
      orderId: 'order-123',
      paymentMethod: PaymentMethodType.cash,
      amountPaid: 50000,
      totalAmount: 50000,
    );

    // NEW WAY (more flexible):
    final newTransaction = await _transactionService.createTransaction(
      transactionType: TransactionType.revenue,
      referenceType: ReferenceType.order,
      referenceId: 'order-123',
      paymentMethod: PaymentMethodType.cash,
      amount: 50000,
      category: 'food_sales',
      subcategory: 'order_payment',
      description: 'Order payment via POS',
      accountFrom: 'customer_cash',
      accountTo: 'revenue_food_sales',
    );

    print('Old method payment ID: ${oldPayment?.id}');
    print('New method transaction ID: ${newTransaction?.id}');
  }
}