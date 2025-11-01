import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../models/order.dart';
import '../../../../models/order_source.dart';
import '../../../../models/customer.dart' as customer_model;
import '../../../../core/providers/supabase_providers.dart';
import '../../../../core/widgets/main_layout.dart' show activeOrdersCountProvider;
import '../../../../services/supabase_service.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  final Order order;

  const CheckoutPage({super.key, required this.order});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {

  // Customer information
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  customer_model.Customer? _foundCustomer;

  // Order sources
  List<OrderSource> _orderSources = [];
  OrderSource? _selectedOrderSource;
  bool _isLoadingOrderSources = true;

  // Payment
  PaymentMethod? _selectedPaymentMethod;

  // Discount
  bool _isPercentageDiscount = true;
  final TextEditingController _discountController = TextEditingController();
  double _discountAmount = 0;

  // Commission
  final TextEditingController _commissionAmountController = TextEditingController();
  double _commissionAmount = 0;
  double _calculatedOtherAmount = 0;

  @override
  void initState() {
    super.initState();
    _loadOrderSources();
    _loadExistingOrderInformation();
    _discountController.addListener(_calculateTotals);
    _commissionAmountController.addListener(_calculateCommission);
  }

  Future<void> _loadOrderSources() async {
    try {
      final orderSourceService = ref.read(supabaseOrderSourceServiceProvider);

      // Initialize default order sources if needed
      await orderSourceService.initializeDefaultOrderSources();

      // Load active order sources from database
      final sources = await orderSourceService.getOrderSources(isActive: true);

      setState(() {
        _orderSources = sources;
        _isLoadingOrderSources = false;

        // Only auto-select order source if this is an existing order being edited (has an ID)
        // For new orders from POS, user should manually select the order source
        // Explicitly check for existing order and matching platform
        if (widget.order.id.isNotEmpty &&
            widget.order.platform.isNotEmpty &&
            widget.order.platform != 'direct' &&
            widget.order.platform != 'POS') {
          _selectedOrderSource = sources.where((source) =>
            source.name.toLowerCase() == widget.order.platform.toLowerCase()
          ).firstOrNull;
        } else {
          // Explicitly ensure no order source is selected for new orders
          _selectedOrderSource = null;
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingOrderSources = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('checkout_page.load_error'.tr(namedArgs: {'error': e.toString()})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _loadExistingOrderInformation() {
    // Load customer information if exists - but skip walk-in customer defaults
    if (widget.order.customer.id.isNotEmpty &&
        widget.order.customer.name.trim().isNotEmpty &&
        widget.order.customer.name != 'Khách vãng lai' &&
        widget.order.customer.name != 'Walk-in Customer') {
      _customerPhoneController.text = widget.order.customer.phone ?? '';
      _customerNameController.text = widget.order.customer.name;
      _foundCustomer = customer_model.Customer(
        id: widget.order.customer.id,
        name: widget.order.customer.name,
        phone: widget.order.customer.phone,
        email: widget.order.customer.email,
        address: widget.order.customer.address,
        createdAt: widget.order.customer.createdAt ?? DateTime.now(),
        updatedAt: widget.order.customer.updatedAt ?? DateTime.now(),
      );
    }

    // Load discount information if exists
    if (widget.order.discount > 0) {
      _discountAmount = widget.order.discount;
      // Calculate back to display value - assume percentage if discount is small relative to subtotal
      if (widget.order.discount < widget.order.subtotal * 0.5) {
        final percentage = (widget.order.discount / widget.order.subtotal) * 100;
        if (percentage <= 100 && percentage % 1 == 0) {
          _isPercentageDiscount = true;
          _discountController.text = percentage.toInt().toString();
        } else {
          _isPercentageDiscount = false;
          _discountController.text = widget.order.discount.toInt().toString();
        }
      } else {
        _isPercentageDiscount = false;
        _discountController.text = widget.order.discount.toInt().toString();
      }
    }

    // Load payment method if exists (only if order has pending payment status)
    if (widget.order.paymentStatus == PaymentStatus.pending) {
      _selectedPaymentMethod = widget.order.paymentMethod;
    }
  }

  @override
  void dispose() {
    _customerPhoneController.dispose();
    _customerNameController.dispose();
    _discountController.dispose();
    _commissionAmountController.dispose();
    super.dispose();
  }

  Future<void> _searchCustomerByPhone(String phone) async {
    // Clear customer if phone is empty or too short
    if (phone.trim().isEmpty) {
      setState(() {
        _foundCustomer = null;
        _customerNameController.clear();
      });
      return;
    }

    if (phone.length >= 3) {
      final customerService = ref.read(supabaseCustomerServiceProvider);
      final customer = await customerService.getCustomerByPhone(phone);
      setState(() {
        _foundCustomer = customer;
        if (customer != null) {
          _customerNameController.text = customer.name;
        } else {
          _customerNameController.clear();
        }
      });
    } else {
      setState(() {
        _foundCustomer = null;
        _customerNameController.clear();
      });
    }
  }

  void _calculateTotals() {
    setState(() {
      final discountValue = double.tryParse(_discountController.text) ?? 0;
      if (_isPercentageDiscount) {
        _discountAmount = widget.order.subtotal * (discountValue / 100);
      } else {
        _discountAmount = discountValue;
      }
    });
  }

  void _calculateCommission() {
    if (_selectedOrderSource == null || !_selectedOrderSource!.requiresCommissionInput) {
      return;
    }

    setState(() {
      final inputAmount = double.tryParse(_commissionAmountController.text) ?? 0;
      _commissionAmount = inputAmount;

      if (_selectedOrderSource!.commissionInputType == CommissionInputType.beforeFee) {
        // User entered amount before fee, calculate amount after fee
        _calculatedOtherAmount = _selectedOrderSource!.calculateAmountAfterFee(inputAmount);
      } else {
        // User entered amount after fee, calculate amount before fee
        _calculatedOtherAmount = _selectedOrderSource!.calculateAmountBeforeFee(inputAmount);
      }
    });
  }

  double get _subtotal => widget.order.subtotal;

  double get _total {
    return _subtotal - _discountAmount;
  }

  double get _commissionFee {
    if (_selectedOrderSource == null || !_selectedOrderSource!.requiresCommissionInput) {
      return 0;
    }

    final amount = double.tryParse(_commissionAmountController.text) ?? 0;
    if (amount == 0) return 0;

    final isBeforeFee = _selectedOrderSource!.commissionInputType == CommissionInputType.beforeFee;
    return _selectedOrderSource!.calculateCommissionFee(amount, isBeforeFee: isBeforeFee);
  }

  Future<void> _saveOrder() async {
    try {
      // Save customer information if provided
      Customer? orderCustomer = widget.order.customer;
      final phone = _customerPhoneController.text.trim();
      final name = _customerNameController.text.trim();

      if (phone.isNotEmpty) {
        if (_foundCustomer != null) {
          // Check if name was changed
          final nameChanged = name.isNotEmpty && name != _foundCustomer!.name;

          if (nameChanged) {
            // Update existing customer with new name
            final updatedCustomer = _foundCustomer!.copyWith(
              name: name,
              updatedAt: DateTime.now(),
            );

            final customerService = ref.read(supabaseCustomerServiceProvider);
            await customerService.updateCustomer(updatedCustomer);
            orderCustomer = Customer(
              id: updatedCustomer.id,
              name: updatedCustomer.name,
              phone: updatedCustomer.phone,
              email: updatedCustomer.email,
              address: updatedCustomer.address,
              createdAt: updatedCustomer.createdAt,
              updatedAt: updatedCustomer.updatedAt,
            );
          } else {
            // Use existing customer without changes
            orderCustomer = Customer(
              id: _foundCustomer!.id,
              name: _foundCustomer!.name,
              phone: _foundCustomer!.phone,
              email: _foundCustomer!.email,
              address: _foundCustomer!.address,
              createdAt: _foundCustomer!.createdAt,
              updatedAt: _foundCustomer!.updatedAt,
            );
          }
        } else {
          // Try searching one more time before creating
          final customerService = ref.read(supabaseCustomerServiceProvider);
          final existingCustomer = await customerService.getCustomerByPhone(phone);
          if (existingCustomer != null) {
            // Found existing customer, use it
            orderCustomer = Customer(
              id: existingCustomer.id,
              name: existingCustomer.name,
              phone: existingCustomer.phone,
              email: existingCustomer.email,
              address: existingCustomer.address,
              createdAt: existingCustomer.createdAt,
              updatedAt: existingCustomer.updatedAt,
            );
          } else {
            // Create new customer
            final newCustomer = customer_model.Customer(
              id: '',
              name: name.isNotEmpty ? name : 'checkout_page.default_customer_name'.tr(),
              phone: phone,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            final customerService = ref.read(supabaseCustomerServiceProvider);
            final customerId = await customerService.createCustomer(newCustomer);
            if (customerId != null) {
              orderCustomer = Customer(
                id: customerId,
                name: newCustomer.name,
                phone: newCustomer.phone,
                email: null,
                address: null,
                createdAt: newCustomer.createdAt,
                updatedAt: newCustomer.updatedAt,
              );
            }
          }
        }
      }

      // Update order with saved information (active status)
      final now = DateTime.now();

      // Create the order object with active status
      final updatedOrder = Order(
        id: widget.order.id,
        orderNumber: widget.order.orderNumber,
        customer: orderCustomer,
        items: widget.order.items,
        subtotal: widget.order.subtotal,
        deliveryFee: widget.order.deliveryFee,
        discount: _discountAmount,
        tax: widget.order.tax,
        serviceCharge: widget.order.serviceCharge,
        total: _total,
        orderType: widget.order.orderType,
        status: OrderStatus.pending, // Active order status
        paymentMethod: _selectedPaymentMethod ?? PaymentMethod.none, // No default payment method
        paymentStatus: PaymentStatus.pending, // Payment pending
        deliveryInfo: widget.order.deliveryInfo,
        tableNumber: widget.order.tableNumber,
        platform: _selectedOrderSource?.name ?? widget.order.platform, // Save the selected order source name or keep existing
        assignedStaff: widget.order.assignedStaff,
        notes: widget.order.notes,
        createdAt: widget.order.createdAt,
        updatedAt: now,
      );

      // Check if this is a new order (empty ID) or existing order update
      final orderService = ref.read(supabaseOrderServiceProvider);
      if (widget.order.id.isEmpty) {
        // Create new order
        await orderService.createOrder(updatedOrder);
        // Update the order number in success message with the new ID
        // (keep using the original orderNumber for display)

        // 🚀 INSTANT BADGE UPDATE: Increment active order count immediately
        ref.read(activeOrdersCountProvider.notifier).incrementCount();
      } else {
        // Update existing order
        await orderService.updateOrder(updatedOrder);
      }

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('checkout_page.order_saved'.tr(namedArgs: {'orderNumber': widget.order.orderNumber})),
            backgroundColor: Colors.green,
          ),
        );

        // Pop with success result
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('checkout_page.save_order_error'.tr(namedArgs: {'error': e.toString()})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _completeCheckout() async {
    // Validate that order source is selected
    if (_selectedOrderSource == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('checkout_page.select_source_error'.tr()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate that payment method is selected
    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('checkout_page.select_payment_error'.tr()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Save customer information if provided
      Customer? orderCustomer = widget.order.customer;
      final phone = _customerPhoneController.text.trim();
      final name = _customerNameController.text.trim();

      if (phone.isNotEmpty) {
        if (_foundCustomer != null) {
          // Check if name was changed
          final nameChanged = name.isNotEmpty && name != _foundCustomer!.name;

          if (nameChanged) {
            // Update existing customer with new name
            final updatedCustomer = _foundCustomer!.copyWith(
              name: name,
              updatedAt: DateTime.now(),
            );

            final customerService = ref.read(supabaseCustomerServiceProvider);
            await customerService.updateCustomer(updatedCustomer);
            orderCustomer = Customer(
              id: updatedCustomer.id,
              name: updatedCustomer.name,
              phone: updatedCustomer.phone,
              email: updatedCustomer.email,
              address: updatedCustomer.address,
              createdAt: updatedCustomer.createdAt,
              updatedAt: updatedCustomer.updatedAt,
            );
          } else {
            // Use existing customer without changes
            orderCustomer = Customer(
              id: _foundCustomer!.id,
              name: _foundCustomer!.name,
              phone: _foundCustomer!.phone,
              email: _foundCustomer!.email,
              address: _foundCustomer!.address,
              createdAt: _foundCustomer!.createdAt,
              updatedAt: _foundCustomer!.updatedAt,
            );
          }
        } else {
          // Try searching one more time before creating
          final customerService = ref.read(supabaseCustomerServiceProvider);
          final existingCustomer = await customerService.getCustomerByPhone(phone);
          if (existingCustomer != null) {
            // Found existing customer, use it
            orderCustomer = Customer(
              id: existingCustomer.id,
              name: existingCustomer.name,
              phone: existingCustomer.phone,
              email: existingCustomer.email,
              address: existingCustomer.address,
              createdAt: existingCustomer.createdAt,
              updatedAt: existingCustomer.updatedAt,
            );
          } else {
            // Create new customer
            final newCustomer = customer_model.Customer(
              id: '',
              name: name.isNotEmpty ? name : 'checkout_page.default_customer_name'.tr(),
              phone: phone,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            final customerService = ref.read(supabaseCustomerServiceProvider);
            final customerId = await customerService.createCustomer(newCustomer);
            if (customerId != null) {
              orderCustomer = Customer(
                id: customerId,
                name: newCustomer.name,
                phone: newCustomer.phone,
                email: null,
                address: null,
                createdAt: newCustomer.createdAt,
                updatedAt: newCustomer.updatedAt,
              );
            }
          }
        }
      }

      // Update order with payment information
      final now = DateTime.now();

      // Create the order object with all required fields
      final updatedOrder = Order(
        id: widget.order.id,
        orderNumber: widget.order.orderNumber,
        customer: orderCustomer,
        items: widget.order.items,
        subtotal: widget.order.subtotal,
        deliveryFee: widget.order.deliveryFee,
        discount: _discountAmount,
        tax: widget.order.tax,
        serviceCharge: widget.order.serviceCharge,
        total: _total,
        orderType: widget.order.orderType,
        status: OrderStatus.delivered,
        paymentMethod: _selectedPaymentMethod!,
        paymentStatus: PaymentStatus.paid,
        deliveryInfo: widget.order.deliveryInfo,
        tableNumber: widget.order.tableNumber,
        platform: _selectedOrderSource!.name, // Save the selected order source name
        assignedStaff: widget.order.assignedStaff,
        notes: widget.order.notes,
        createdAt: widget.order.createdAt,
        updatedAt: now,
      );

      // Check if this is a new order (empty ID) or existing order update
      final orderService = ref.read(supabaseOrderServiceProvider);
      if (widget.order.id.isEmpty) {
        // Create new order
        await orderService.createOrder(updatedOrder);

        // 🚀 INSTANT BADGE UPDATE: Increment active order count immediately
        ref.read(activeOrdersCountProvider.notifier).incrementCount();
      } else {
        // Update existing order
        await orderService.updateOrder(updatedOrder);
      }

      // 🆕 Automatically create finance income entry when order is delivered
      await _createFinanceIncomeEntry(updatedOrder);

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('checkout_page.payment_success'.tr(namedArgs: {'orderNumber': widget.order.orderNumber})),
            backgroundColor: Colors.green,
          ),
        );

        // Pop with success result
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        // Check if it's a payment method validation error
        String errorMessage;
        if (e.toString().contains('Payment method is required')) {
          errorMessage = 'checkout_page.select_payment_error'.tr();
        } else {
          errorMessage = 'checkout_page.payment_error'.tr(namedArgs: {'error': e.toString()});
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Automatically create a finance income entry when an order is delivered
  Future<void> _createFinanceIncomeEntry(Order order) async {
    try {
      final financeService = SupabaseFinanceService();

      // Calculate net amount after commission (if applicable)
      double netAmount = order.total;
      String incomeDescription = 'Order ${order.orderNumber}';

      // If commission was charged, subtract it from the income
      if (_commissionAmount > 0) {
        netAmount = order.total - _commissionAmount;
        incomeDescription += ' (Net after ${_selectedOrderSource?.name} commission)';
      }

      // Add order ID to description for better tracking and duplicate prevention
      incomeDescription += ' [ID: ${order.id}]';

      // Create income entry for the order
      await financeService.createFinanceEntry(
        type: 'income',
        amount: netAmount,
        description: incomeDescription,
        category: 'Sales - ${_selectedOrderSource?.name ?? 'Direct'}',
      );

      // If there was commission, also create an expense entry for the commission
      if (_commissionAmount > 0) {
        await financeService.createFinanceEntry(
          type: 'expense',
          amount: _commissionAmount,
          description: 'Commission for Order ${order.orderNumber} [ID: ${order.id}]',
          category: 'Commission - ${_selectedOrderSource?.name}',
        );
      }

      debugPrint('✅ Finance entries created for order ${order.orderNumber}: Income: ${netAmount}đ, Commission: $_commissionAmountđ');
    } catch (e) {
      debugPrint('❌ Error creating finance entry for order ${order.orderNumber}: $e');
      // Don't throw the error - we don't want to fail the checkout if finance entry creation fails
      // The order completion is more important than the finance tracking
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('checkout_page.title'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Information Section
                  _buildCustomerInformationSection(),
                  const SizedBox(height: 24),

                  // Order Source Selection
                  _buildOrderSourceSelection(),
                  const SizedBox(height: 24),

                  // Commission Section (for delivery platforms)
                  if (_selectedOrderSource?.requiresCommissionInput == true) ...[
                    _buildCommissionSection(),
                    const SizedBox(height: 24),
                  ],

                  // Discount Section
                  _buildDiscountSection(),
                  const SizedBox(height: 24),

                  // Payment Method Section
                  _buildPaymentMethodSection(),
                  const SizedBox(height: 24),

                  // Order Summary
                  _buildOrderSummary(),
                ],
              ),
            ),
          ),

          // Bottom Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Save Order button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saveOrder,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange[700],
                        side: BorderSide(color: Colors.orange[700]!),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'checkout_page.save_order'.tr(),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Complete Payment button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _completeCheckout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'checkout_page.complete_payment'.tr(),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInformationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'checkout_page.customer_info'.tr(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Phone input
        TextField(
          controller: _customerPhoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'checkout_page.phone_field'.tr(),
            hintText: 'checkout_page.phone_placeholder'.tr(),
            prefixIcon: const Icon(Icons.phone),
            border: const OutlineInputBorder(),
          ),
          onChanged: _searchCustomerByPhone,
        ),
        const SizedBox(height: 12),

        // Show indicator if customer found and phone field has content
        if (_foundCustomer != null && _customerPhoneController.text.trim().isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'checkout_page.existing_customer'.tr(),
                    style: TextStyle(color: Colors.green[700], fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

        // Name input
        TextField(
          controller: _customerNameController,
          decoration: InputDecoration(
            labelText: 'checkout_page.customer_name_field'.tr(),
            hintText: 'checkout_page.customer_name_placeholder'.tr(),
            prefixIcon: const Icon(Icons.person),
            border: const OutlineInputBorder(),
            helperText: 'checkout_page.auto_save_hint'.tr(),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderSourceSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'checkout_page.order_source_section'.tr(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            Text(
              '*',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingOrderSources)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_orderSources.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange[800]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'checkout_page.no_order_sources'.tr(),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 3.5,
            ),
            itemCount: _orderSources.length,
            itemBuilder: (context, index) {
              final source = _orderSources[index];
              final isSelected = _selectedOrderSource?.id == source.id;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedOrderSource = source;
                    _commissionAmountController.clear();
                    _commissionAmount = 0;
                    _calculatedOtherAmount = 0;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isSelected ? Colors.blue[50] : Colors.white,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildOrderSourceIcon(source.iconPath),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          source.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.blue[800] : Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildOrderSourceIcon(String iconPath) {
    IconData iconData;
    Color iconColor;

    switch (iconPath.toLowerCase()) {
      case 'onsite':
        iconData = Icons.restaurant;
        iconColor = Colors.teal;
        break;
      case 'takeaway':
        iconData = Icons.shopping_bag;
        iconColor = Colors.teal;
        break;
      case 'shopee':
        iconData = Icons.shopping_cart;
        iconColor = Colors.orange;
        break;
      case 'grabfood':
        iconData = Icons.delivery_dining;
        iconColor = Colors.green;
        break;
      default:
        iconData = Icons.store;
        iconColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, size: 16, color: iconColor),
    );
  }

  Widget _buildCommissionSection() {
    if (_selectedOrderSource == null || !_selectedOrderSource!.requiresCommissionInput) {
      return const SizedBox.shrink();
    }

    final isBeforeFee = _selectedOrderSource!.commissionInputType == CommissionInputType.beforeFee;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: Colors.orange[800]),
              const SizedBox(width: 8),
              Text(
                'checkout_page.commission_section'.tr(namedArgs: {'source': _selectedOrderSource!.name}),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Commission rate
          Text(
            'checkout_page.commission_rate'.tr(namedArgs: {'rate': _selectedOrderSource!.commissionRate.toStringAsFixed(0)}),
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          const SizedBox(height: 12),

          // Input field
          TextField(
            controller: _commissionAmountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: isBeforeFee ? 'checkout_page.amount_before_fee'.tr() : 'checkout_page.amount_after_fee'.tr(),
              hintText: 'checkout_page.amount_placeholder'.tr(),
              suffixText: 'đ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),

          if (_commissionAmount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isBeforeFee ? 'checkout_page.calculated_amount_after'.tr() : 'checkout_page.calculated_amount_before'.tr(),
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      Text(
                        '${_calculatedOtherAmount.toStringAsFixed(0)}đ',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'checkout_page.commission_fee'.tr(),
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      Text(
                        '${_commissionFee.toStringAsFixed(0)}đ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiscountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'checkout_page.discount_section'.tr(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isPercentageDiscount = true;
                            _discountController.clear();
                            _calculateTotals();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isPercentageDiscount ? Colors.blue : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              bottomLeft: Radius.circular(8),
                            ),
                          ),
                          child: Text(
                            '%',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _isPercentageDiscount ? Colors.white : Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isPercentageDiscount = false;
                            _discountController.clear();
                            _calculateTotals();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isPercentageDiscount ? Colors.blue : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: Text(
                            'đ',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: !_isPercentageDiscount ? Colors.white : Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _discountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: _isPercentageDiscount ? 'checkout_page.discount_placeholder_percent'.tr() : 'checkout_page.discount_placeholder_amount'.tr(),
                  suffixText: _isPercentageDiscount ? '%' : 'đ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentMethodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'checkout_page.payment_method_section'.tr(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            Text(
              '*',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'checkout_page.payment_method_required_note'.tr(),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: _selectedPaymentMethod == null ? Colors.red[300]! : Colors.grey[300]!,
              width: _selectedPaymentMethod == null ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildPaymentMethodTile(
                PaymentMethod.cash,
                'checkout_page.payment_cash'.tr(),
                Icons.money,
              ),
              Divider(height: 1, color: Colors.grey[300]),
              _buildPaymentMethodTile(
                PaymentMethod.card,
                'checkout_page.payment_card'.tr(),
                Icons.credit_card,
              ),
              Divider(height: 1, color: Colors.grey[300]),
              _buildPaymentMethodTile(
                PaymentMethod.digitalWallet,
                'checkout_page.payment_ewallet'.tr(),
                Icons.account_balance_wallet,
              ),
              Divider(height: 1, color: Colors.grey[300]),
              _buildPaymentMethodTile(
                PaymentMethod.bankTransfer,
                'checkout_page.payment_bank_transfer'.tr(),
                Icons.account_balance,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodTile(PaymentMethod method, String label, IconData icon) {
    final isSelected = _selectedPaymentMethod == method;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = method;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isSelected ? Colors.blue[50] : Colors.transparent,
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue : Colors.grey[600],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? Colors.blue[800] : Colors.grey[800],
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.blue, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'checkout_page.order_summary'.tr(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'checkout_page.subtotal_label'.tr(),
                style: TextStyle(fontSize: 15, color: Colors.grey[700]),
              ),
              Text(
                '${_subtotal.toStringAsFixed(0)}đ',
                style: const TextStyle(fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'checkout_page.discount_label'.tr(),
                style: TextStyle(fontSize: 15, color: Colors.grey[700]),
              ),
              Text(
                '-${_discountAmount.toStringAsFixed(0)}đ',
                style: const TextStyle(fontSize: 15, color: Colors.orange),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'checkout_page.total_label'.tr(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_total.toStringAsFixed(0)}đ',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
