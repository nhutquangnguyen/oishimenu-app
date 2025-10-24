import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/order.dart';
import '../../../../models/order_source.dart';
import '../../../../models/customer.dart' as customer_model;
import '../../../../services/order_service.dart';
import '../../../../services/order_source_service.dart';
import '../../../../services/customer_service.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  final Order order;

  const CheckoutPage({super.key, required this.order});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final OrderService _orderService = OrderService();
  final OrderSourceService _orderSourceService = OrderSourceService();
  final CustomerService _customerService = CustomerService();

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
    _discountController.addListener(_calculateTotals);
    _commissionAmountController.addListener(_calculateCommission);
  }

  Future<void> _loadOrderSources() async {
    try {
      // Initialize default order sources if needed
      await _orderSourceService.initializeDefaultOrderSources();

      // Load active order sources from database
      final sources = await _orderSourceService.getOrderSources(isActive: true);

      setState(() {
        _orderSources = sources;
        _isLoadingOrderSources = false;
        // Do not auto-select - user must choose explicitly
      });
    } catch (e) {
      setState(() {
        _isLoadingOrderSources = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải nguồn đơn hàng: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    if (phone.length >= 9) {
      final customer = await _customerService.getCustomerByPhone(phone);
      setState(() {
        _foundCustomer = customer;
        if (customer != null) {
          _customerNameController.text = customer.name;
        }
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

  Future<void> _completeCheckout() async {
    // Validate that order source is selected
    if (_selectedOrderSource == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn nguồn đơn hàng'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate that payment method is selected
    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn phương thức thanh toán'),
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

            await _customerService.updateCustomer(updatedCustomer);
            orderCustomer = Customer(
              id: updatedCustomer.id,
              name: updatedCustomer.name,
              phone: updatedCustomer.phone,
              email: updatedCustomer.email,
              address: updatedCustomer.address,
            );
          } else {
            // Use existing customer without changes
            orderCustomer = Customer(
              id: _foundCustomer!.id,
              name: _foundCustomer!.name,
              phone: _foundCustomer!.phone,
              email: _foundCustomer!.email,
              address: _foundCustomer!.address,
            );
          }
        } else {
          // Create new customer
          final newCustomer = customer_model.Customer(
            id: '',
            name: name.isNotEmpty ? name : 'Khách',
            phone: phone,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          final customerId = await _customerService.createCustomer(newCustomer);
          if (customerId != null) {
            orderCustomer = Customer(
              id: customerId,
              name: newCustomer.name,
              phone: newCustomer.phone,
              email: null,
              address: null,
            );
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
        platform: widget.order.platform,
        assignedStaff: widget.order.assignedStaff,
        notes: widget.order.notes,
        createdAt: widget.order.createdAt,
        updatedAt: now,
      );

      await _orderService.updateOrder(updatedOrder);

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đơn hàng ${widget.order.orderNumber} đã thanh toán thành công'),
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
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thanh toán'),
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

          // Bottom Apply Button
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
              child: SizedBox(
                width: double.infinity,
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
                  child: const Text(
                    'Hoàn tất thanh toán',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
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
        const Text(
          'Thông tin khách hàng',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Phone input
        TextField(
          controller: _customerPhoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Số điện thoại',
            hintText: 'Nhập số điện thoại',
            prefixIcon: Icon(Icons.phone),
            border: OutlineInputBorder(),
          ),
          onChanged: _searchCustomerByPhone,
        ),
        const SizedBox(height: 12),

        // Show indicator if customer found
        if (_foundCustomer != null)
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
                    'Khách hàng đã tồn tại',
                    style: TextStyle(color: Colors.green[700], fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

        // Name input
        TextField(
          controller: _customerNameController,
          decoration: const InputDecoration(
            labelText: 'Tên khách hàng (tùy chọn)',
            hintText: 'Nhập tên',
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(),
            helperText: 'Tự động lưu khi thanh toán',
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
            const Text(
              'Nguồn đơn hàng',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                const Expanded(
                  child: Text(
                    'Không có nguồn đơn hàng nào. Vui lòng vào Cài đặt để thêm nguồn đơn hàng.',
                    style: TextStyle(fontSize: 14),
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
                'Hoa hồng ${_selectedOrderSource!.name}',
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
            'Tỷ lệ hoa hồng: ${_selectedOrderSource!.commissionRate.toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          const SizedBox(height: 12),

          // Input field
          TextField(
            controller: _commissionAmountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: isBeforeFee ? 'Số tiền trước phí' : 'Số tiền sau phí',
              hintText: 'Nhập số tiền',
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
                        isBeforeFee ? 'Số tiền sau phí:' : 'Số tiền trước phí:',
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
                        'Phí hoa hồng:',
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
        const Text(
          'Giảm giá',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                  hintText: _isPercentageDiscount ? 'Nhập %' : 'Nhập số tiền',
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
            const Text(
              'Phương thức thanh toán',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildPaymentMethodTile(
                PaymentMethod.cash,
                'Tiền mặt',
                Icons.money,
              ),
              Divider(height: 1, color: Colors.grey[300]),
              _buildPaymentMethodTile(
                PaymentMethod.card,
                'Thẻ',
                Icons.credit_card,
              ),
              Divider(height: 1, color: Colors.grey[300]),
              _buildPaymentMethodTile(
                PaymentMethod.digitalWallet,
                'Ví điện tử',
                Icons.account_balance_wallet,
              ),
              Divider(height: 1, color: Colors.grey[300]),
              _buildPaymentMethodTile(
                PaymentMethod.bankTransfer,
                'Chuyển khoản',
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
              Icon(Icons.check_circle, color: Colors.blue, size: 20),
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
          const Text(
            'Tóm tắt đơn hàng',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tạm tính:',
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
                'Giảm giá:',
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
              const Text(
                'Tổng cộng:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
