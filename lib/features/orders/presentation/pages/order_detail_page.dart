import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/order.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../../core/widgets/main_layout.dart' show activeOrdersCountProvider;

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

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _loadOrderData();
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
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Complete',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
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
}