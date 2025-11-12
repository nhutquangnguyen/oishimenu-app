import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/order.dart';
import '../../../../models/payment_method.dart';
import '../../../../services/transaction_service.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../../core/widgets/main_layout.dart' show activeOrdersCountProvider;
import '../../../payments/widgets/payment_method_selector.dart';
import '../../../payments/widgets/payment_dialog.dart';

class OrderDetailPage extends ConsumerStatefulWidget {
  final Order order;

  const OrderDetailPage({super.key, required this.order});

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  late Order _currentOrder;
  final TextEditingController _orderNotesController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  bool _isDiscountPercentage = false;

  // Payment-related state
  final TransactionService _transactionService = TransactionService();
  List<PaymentInfo> _payments = [];
  bool _isLoadingPayments = false;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _loadOrderData();
    _loadPaymentData();
  }

  void _loadOrderData() {
    // Load existing order data into controllers
    _orderNotesController.text = _currentOrder.notes ?? '';
    _customerNameController.text = _currentOrder.customer.name;
    _customerPhoneController.text = _currentOrder.customer.phone ?? '';

    // Load discount (simplified for now)
    if (_currentOrder.discount > 0) {
      _discountController.text = _currentOrder.discount.toString();
    }
  }

  @override
  void dispose() {
    _orderNotesController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _increaseQuantity(int itemIndex) {
    setState(() {
      final updatedItems = List<OrderItem>.from(_currentOrder.items);
      final item = updatedItems[itemIndex];
      final newQuantity = item.quantity + 1;
      final newSubtotal = item.basePrice * newQuantity;

      updatedItems[itemIndex] = OrderItem(
        id: item.id,
        menuItemId: item.menuItemId,
        menuItemName: item.menuItemName,
        basePrice: item.basePrice,
        quantity: newQuantity,
        selectedOptions: item.selectedOptions,
        subtotal: newSubtotal,
        notes: item.notes,
      );

      final newTotal = updatedItems.fold(0.0, (sum, item) => sum + item.subtotal);
      _currentOrder = _currentOrder.copyWith(
        items: updatedItems,
        subtotal: newTotal,
        total: newTotal,
        updatedAt: DateTime.now(),
      );
    });
  }

  void _decreaseQuantity(int itemIndex) {
    setState(() {
      final updatedItems = List<OrderItem>.from(_currentOrder.items);
      final item = updatedItems[itemIndex];

      if (item.quantity > 1) {
        final newQuantity = item.quantity - 1;
        final newSubtotal = item.basePrice * newQuantity;

        updatedItems[itemIndex] = OrderItem(
          id: item.id,
          menuItemId: item.menuItemId,
          menuItemName: item.menuItemName,
          basePrice: item.basePrice,
          quantity: newQuantity,
          selectedOptions: item.selectedOptions,
          subtotal: newSubtotal,
          notes: item.notes,
        );
      } else {
        // Remove item if quantity would be 0
        updatedItems.removeAt(itemIndex);
      }

      final newTotal = updatedItems.fold(0.0, (sum, item) => sum + item.subtotal);
      _currentOrder = _currentOrder.copyWith(
        items: updatedItems,
        subtotal: newTotal,
        total: newTotal,
        updatedAt: DateTime.now(),
      );
    });
  }

  Future<void> _saveOrder() async {
    try {
      // Update order with current form data
      final updatedCustomer = Customer(
        id: _currentOrder.customer.id,
        name: _customerNameController.text.trim(),
        phone: _customerPhoneController.text.trim(),
        email: _currentOrder.customer.email,
        address: _currentOrder.customer.address,
        createdAt: _currentOrder.customer.createdAt,
        updatedAt: DateTime.now(),
      );

      double discountAmount = 0.0;
      if (_discountController.text.isNotEmpty) {
        discountAmount = double.tryParse(_discountController.text) ?? 0.0;
        if (_isDiscountPercentage) {
          discountAmount = (_currentOrder.subtotal * discountAmount / 100);
        }
      }

      final updatedOrder = _currentOrder.copyWith(
        customer: updatedCustomer,
        notes: _orderNotesController.text.trim(),
        discount: discountAmount,
        total: _currentOrder.subtotal - discountAmount,
        updatedAt: DateTime.now(),
      );

      final orderService = ref.read(supabaseOrderServiceProvider);
      await orderService.updateOrder(updatedOrder);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _completeOrder() async {
    try {
      // Check if order is fully paid before allowing completion
      debugPrint('_completeOrder: Checking payment status. Remaining amount: $_remainingAmount');

      if (_remainingAmount > 0) {
        debugPrint('_completeOrder: Order not fully paid, showing payment dialog');
        _showPaymentRequiredDialog();
        return;
      }

      debugPrint('_completeOrder: Order is fully paid, proceeding with completion');

      // First save any changes
      await _saveOrder();

      // Then mark as delivered
      final completedOrder = _currentOrder.copyWith(
        status: OrderStatus.delivered,
        paymentStatus: PaymentStatus.paid,
        updatedAt: DateTime.now(),
      );

      final orderService = ref.read(supabaseOrderServiceProvider);
      await orderService.updateOrder(completedOrder);

      // Update active orders count
      ref.read(activeOrdersCountProvider.notifier).decrementCount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('_completeOrder: Error occurred: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  double get _calculatedTotal {
    double subtotal = _currentOrder.subtotal;
    double discountAmount = 0.0;

    if (_discountController.text.isNotEmpty) {
      discountAmount = double.tryParse(_discountController.text) ?? 0.0;
      if (_isDiscountPercentage) {
        discountAmount = (subtotal * discountAmount / 100);
      }
    }

    return subtotal - discountAmount;
  }

  // Payment-related methods
  Future<void> _loadPaymentData() async {
    if (_currentOrder.id.isEmpty) return; // Skip for new orders

    setState(() => _isLoadingPayments = true);
    try {
      final payments = await _transactionService.getPaymentsForOrder(_currentOrder.id);
      setState(() {
        _payments = payments;
        _isLoadingPayments = false;
      });
    } catch (e) {
      debugPrint('_loadPaymentData: Error loading payments (likely table not created yet): $e');
      setState(() {
        _payments = []; // Empty payments list if service fails
        _isLoadingPayments = false;
      });
      // Don't show error message - payment system might not be set up yet
    }
  }

  double get _totalPaidAmount {
    return _payments
        .where((payment) => payment.paymentStatus == PaymentStatus.paid)
        .fold(0.0, (sum, payment) => sum + payment.amountPaid);
  }

  double get _remainingAmount {
    return _calculatedTotal - _totalPaidAmount;
  }

  void _showAddPaymentDialog() {
    if (_currentOrder.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please save the order first before adding payments'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => PaymentDialog(
        orderId: _currentOrder.id,
        totalAmount: _calculatedTotal,
        alreadyPaidAmount: _totalPaidAmount,
        onPaymentAdded: (payment) {
          _loadPaymentData(); // Reload payment data
        },
      ),
    );
  }

  void _showEditPaymentDialog(PaymentInfo payment) {
    showDialog(
      context: context,
      builder: (context) => PaymentDialog(
        orderId: _currentOrder.id,
        totalAmount: _calculatedTotal,
        alreadyPaidAmount: _totalPaidAmount - payment.amountPaid,
        existingPayment: payment,
        onPaymentAdded: (updatedPayment) {
          _loadPaymentData(); // Reload payment data
        },
      ),
    );
  }

  Future<void> _deletePayment(PaymentInfo payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment'),
        content: const Text('Are you sure you want to delete this payment record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _transactionService.deleteTransaction(payment.id);
        await _transactionService.updateOrderPaymentStatus(_currentOrder.id);
        await _loadPaymentData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting payment: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Quick payment methods
  Future<void> _addQuickPayment(PaymentMethodType paymentMethod, double amount) async {
    if (_currentOrder.id.isEmpty) return;

    try {
      await _transactionService.createOrderPayment(
        orderId: _currentOrder.id,
        paymentMethod: paymentMethod,
        amountPaid: amount,
        totalAmount: _calculatedTotal,
        paymentStatus: PaymentStatus.paid,
        notes: 'Quick payment from order detail',
      );

      // Update order payment status
      await _transactionService.updateOrderPaymentStatus(_currentOrder.id);

      // Reload payment data
      await _loadPaymentData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment of ₫${amount.toStringAsFixed(0)} added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildQuickPaymentActions() {
    return Column(
      children: [
        // Payment method buttons
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PaymentMethodType.values.map((method) {
            return _buildPaymentMethodButton(method);
          }).toList(),
        ),
        const SizedBox(height: 12),
        // Quick amount buttons
        Row(
          children: [
            Expanded(
              child: _buildQuickAmountButton(
                'Pay Remaining',
                _remainingAmount,
                Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildQuickAmountButton(
                'Pay Half',
                _remainingAmount / 2,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildQuickAmountButton(
                'Custom',
                null,
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  PaymentMethodType? _selectedQuickPaymentMethod;

  Widget _buildPaymentMethodButton(PaymentMethodType method) {
    final isSelected = _selectedQuickPaymentMethod == method;
    return InkWell(
      onTap: () => setState(() => _selectedQuickPaymentMethod = method),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
              : Colors.white,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              method.icon,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 6),
            Text(
              method.displayName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAmountButton(String label, double? amount, Color color) {
    return ElevatedButton(
      onPressed: () {
        if (_selectedQuickPaymentMethod == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a payment method first'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        if (amount != null) {
          _addQuickPayment(_selectedQuickPaymentMethod!, amount);
        } else {
          // Show custom amount dialog
          _showCustomAmountDialog();
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          if (amount != null)
            Text(
              '₫${amount.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 10),
            ),
        ],
      ),
    );
  }

  void _showCustomAmountDialog() {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom Payment Amount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Payment Method: ${_selectedQuickPaymentMethod!.displayName}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Amount (VND)',
                prefixText: '₫',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                Navigator.of(context).pop();
                _addQuickPayment(_selectedQuickPaymentMethod!, amount);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid amount'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Add Payment'),
          ),
        ],
      ),
    );
  }

  void _showPaymentRequiredDialog() {
    debugPrint('_showPaymentRequiredDialog: Called with remaining amount: $_remainingAmount');
    try {
      showDialog(
        context: context,
        builder: (context) {
          debugPrint('_showPaymentRequiredDialog: Building dialog');
          return _QuickPaymentCompletionDialog(
            orderTotal: _calculatedTotal,
            totalPaidAmount: _totalPaidAmount,
            remainingAmount: _remainingAmount,
            onQuickPayment: (paymentMethod) async {
              debugPrint('_showPaymentRequiredDialog: Quick payment selected: $paymentMethod');
              Navigator.of(context).pop();
              await _addQuickPayment(paymentMethod, _remainingAmount);
              // Auto-complete after payment
              await _completeOrder();
            },
            onAddPayment: () {
              debugPrint('_showPaymentRequiredDialog: Add payment selected');
              Navigator.of(context).pop();
              _showAddPaymentDialog();
            },
            onCancel: () {
              debugPrint('_showPaymentRequiredDialog: Cancelled');
              Navigator.of(context).pop();
            },
          );
        },
      );
    } catch (e) {
      debugPrint('_showPaymentRequiredDialog: Error showing dialog: $e');
      // Fallback to old payment dialog
      _showAddPaymentDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Order'),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Editing Order Banner
            if (_currentOrder.orderNumber.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Editing Order ${_currentOrder.orderNumber}',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            // Ordered Dishes Section
            Text(
              'Ordered Dishes',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // Order Items
            ..._currentOrder.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildOrderItem(item, index);
            }),

            const SizedBox(height: 16),

            // Add More Items Button
            InkWell(
              onTap: () {
                // Navigate back to POS to add more items
                Navigator.pop(context);
                // TODO: Navigate to POS with current order
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Add More Items',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Order Note Section
            _buildOrderNoteSection(),

            const SizedBox(height: 24),

            // Customer Info Section
            _buildCustomerSection(),

            const SizedBox(height: 24),

            // Discount Section
            _buildDiscountSection(),

            const SizedBox(height: 24),

            // Total Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_calculatedTotal.toStringAsFixed(0)}đ',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Payment Section
            _buildPaymentSection(),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Order',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _completeOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _remainingAmount > 0 ? Colors.grey[400] : Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_remainingAmount > 0) ...[
                          const Icon(Icons.warning_amber_rounded, size: 18),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          _remainingAmount > 0 ? 'Payment Required' : 'Complete',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(OrderItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.menuItemName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.basePrice.toStringAsFixed(0)}đ per item',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => _decreaseQuantity(index),
                icon: const Icon(Icons.remove_circle_outline),
                color: Colors.red,
                iconSize: 28,
              ),
              const SizedBox(width: 8),
              Text(
                '${item.quantity}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _increaseQuantity(index),
                icon: const Icon(Icons.add_circle_outline),
                color: Colors.green,
                iconSize: 28,
              ),
            ],
          ),
          const SizedBox(width: 16),
          Text(
            '${item.subtotal.toStringAsFixed(0)}đ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderNoteSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note, color: Colors.orange[700], size: 20),
              const SizedBox(width: 8),
              const Text(
                'Order Note',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _orderNotesController,
            decoration: const InputDecoration(
              hintText: 'Add any special instructions...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              const Text(
                'Customer Info (Optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customerNameController,
                  decoration: const InputDecoration(
                    hintText: 'Name',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _customerPhoneController,
                  decoration: const InputDecoration(
                    hintText: 'Phone',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.percent, color: Colors.green[700], size: 20),
              const SizedBox(width: 8),
              const Text(
                'Discount',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _isDiscountPercentage = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: !_isDiscountPercentage
                          ? Colors.green
                          : Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'đ',
                        style: TextStyle(
                          color: !_isDiscountPercentage
                            ? Colors.white
                            : Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _isDiscountPercentage = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isDiscountPercentage
                          ? Colors.green
                          : Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '%',
                        style: TextStyle(
                          color: _isDiscountPercentage
                            ? Colors.white
                            : Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _discountController,
            decoration: InputDecoration(
              hintText: _isDiscountPercentage ? 'Enter percentage' : 'Enter amount',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.all(12),
              suffixText: _isDiscountPercentage ? '%' : 'đ',
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) => setState(() {}), // Trigger rebuild for total calculation
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payment, size: 20),
              const SizedBox(width: 8),
              Text(
                'Payment Information',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_currentOrder.id.isNotEmpty) // Only show if order is saved
                TextButton.icon(
                  onPressed: _showAddPaymentDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Payment'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).primaryColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Payment Summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Order Total:'),
                    Text(
                      '₫${_calculatedTotal.toStringAsFixed(0).replaceAllMapped(
                        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                        (Match m) => '${m[1]},',
                      )}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if (_totalPaidAmount > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Paid:'),
                      Text(
                        '₫${_totalPaidAmount.toStringAsFixed(0).replaceAllMapped(
                          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                          (Match m) => '${m[1]},',
                        )}',
                        style: TextStyle(
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Remaining:'),
                      Text(
                        '₫${_remainingAmount.toStringAsFixed(0).replaceAllMapped(
                          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                          (Match m) => '${m[1]},',
                        )}',
                        style: TextStyle(
                          color: _remainingAmount > 0 ? Colors.orange.shade600 : Colors.green.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Quick Payment Actions (only show if order is saved and has remaining amount)
          if (_currentOrder.id.isNotEmpty && _remainingAmount > 0) ...[
            Text(
              'Quick Payment',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            _buildQuickPaymentActions(),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
          ],

          // Payment Records
          if (_isLoadingPayments)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_payments.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Icon(Icons.payment_outlined, size: 32, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    _currentOrder.id.isEmpty
                        ? 'Save the order first to add payments'
                        : 'No payments recorded yet',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Column(
              children: _payments.map((payment) => _buildPaymentItem(payment)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentItem(PaymentInfo payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Expanded(
            child: PaymentMethodDisplay(
              method: payment.paymentMethod,
              status: payment.paymentStatus,
              amount: payment.amountPaid,
              transactionId: payment.transactionId,
              paymentTime: payment.paymentTime,
              compact: true,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  _showEditPaymentDialog(payment);
                  break;
                case 'delete':
                  _deletePayment(payment);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 16),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            child: const Icon(Icons.more_vert, size: 16),
          ),
        ],
      ),
    );
  }
}

class _QuickPaymentCompletionDialog extends StatefulWidget {
  final double orderTotal;
  final double totalPaidAmount;
  final double remainingAmount;
  final Function(PaymentMethodType) onQuickPayment;
  final VoidCallback onAddPayment;
  final VoidCallback onCancel;

  const _QuickPaymentCompletionDialog({
    required this.orderTotal,
    required this.totalPaidAmount,
    required this.remainingAmount,
    required this.onQuickPayment,
    required this.onAddPayment,
    required this.onCancel,
  });

  @override
  State<_QuickPaymentCompletionDialog> createState() => _QuickPaymentCompletionDialogState();
}

class _QuickPaymentCompletionDialogState extends State<_QuickPaymentCompletionDialog> {
  PaymentMethodType? _selectedMethod;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.payment_rounded, color: Colors.orange[600]),
          const SizedBox(width: 8),
          const Text('Complete Payment'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This order needs payment to be completed.'),
          const SizedBox(height: 16),

          // Payment summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Order Total:'),
                    Text(
                      '₫${widget.orderTotal.toStringAsFixed(0).replaceAllMapped(
                        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                        (Match m) => '${m[1]},',
                      )}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if (widget.totalPaidAmount > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Already Paid:'),
                      Text(
                        '₫${widget.totalPaidAmount.toStringAsFixed(0).replaceAllMapped(
                          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                          (Match m) => '${m[1]},',
                        )}',
                        style: TextStyle(
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Amount to Pay:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '₫${widget.remainingAmount.toStringAsFixed(0).replaceAllMapped(
                          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                          (Match m) => '${m[1]},',
                        )}',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Payment method selection
          const Text(
            'Choose payment method:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PaymentMethodType.values.map((method) {
              final isSelected = _selectedMethod == method;
              return InkWell(
                onTap: () => setState(() => _selectedMethod = method),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    color: isSelected
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                        : Colors.white,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        method.icon,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        method.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: widget.onAddPayment,
          child: const Text('Custom Amount'),
        ),
        ElevatedButton(
          onPressed: _selectedMethod != null
              ? () => widget.onQuickPayment(_selectedMethod!)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
          ),
          child: const Text('Pay & Complete'),
        ),
      ],
    );
  }
}