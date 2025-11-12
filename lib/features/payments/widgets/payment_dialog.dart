import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/payment_method.dart';
import '../../../models/order.dart';
import '../../../services/transaction_service.dart';
import 'payment_method_selector.dart';

class PaymentDialog extends StatefulWidget {
  final String orderId;
  final double totalAmount;
  final double alreadyPaidAmount;
  final PaymentInfo? existingPayment; // For editing existing payment
  final Function(PaymentInfo) onPaymentAdded;

  const PaymentDialog({
    super.key,
    required this.orderId,
    required this.totalAmount,
    this.alreadyPaidAmount = 0.0,
    this.existingPayment,
    required this.onPaymentAdded,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _transactionIdController = TextEditingController();
  final _notesController = TextEditingController();
  final _transactionService = TransactionService();

  PaymentMethodType _selectedMethod = PaymentMethodType.cash;
  PaymentStatus _selectedStatus = PaymentStatus.paid;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.existingPayment != null) {
      // Editing existing payment
      final payment = widget.existingPayment!;
      _selectedMethod = payment.paymentMethod;
      _selectedStatus = payment.paymentStatus;
      _amountController.text = payment.amountPaid.toStringAsFixed(0);
      _transactionIdController.text = payment.transactionId ?? '';
      _notesController.text = payment.notes ?? '';
    } else {
      // New payment - suggest remaining amount
      final remainingAmount = widget.totalAmount - widget.alreadyPaidAmount;
      if (remainingAmount > 0) {
        _amountController.text = remainingAmount.toStringAsFixed(0);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _transactionIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text);

      PaymentInfo payment;
      if (widget.existingPayment != null) {
        // Update existing payment
        final updatedTransaction = await _transactionService.updateTransaction(
          widget.existingPayment!.id,
          paymentMethod: _selectedMethod,
          paymentStatus: _selectedStatus,
          amount: amount,
          transactionId: _transactionIdController.text.isNotEmpty
              ? _transactionIdController.text
              : null,
          notes: _notesController.text.isNotEmpty
              ? _notesController.text
              : null,
        );
        // Convert Transaction back to PaymentInfo for compatibility
        if (updatedTransaction != null) {
          payment = updatedTransaction.toPaymentInfo();
        } else {
          throw Exception('Failed to update payment');
        }
      } else {
        // Create new payment
        final newPayment = await _transactionService.createOrderPayment(
          orderId: widget.orderId,
          paymentMethod: _selectedMethod,
          amountPaid: amount,
          totalAmount: widget.totalAmount,
          paymentStatus: _selectedStatus,
          transactionId: _transactionIdController.text.isNotEmpty
              ? _transactionIdController.text
              : null,
          notes: _notesController.text.isNotEmpty
              ? _notesController.text
              : null,
        );

        if (newPayment != null) {
          payment = newPayment;
        } else {
          throw Exception('Failed to create payment');
        }
      }

      // Update order payment status
      await _transactionService.updateOrderPaymentStatus(widget.orderId);

      widget.onPaymentAdded(payment);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingPayment != null
                ? 'Payment updated successfully'
                : 'Payment added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingPayment != null;
    final remainingAmount = widget.totalAmount - widget.alreadyPaidAmount;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit_rounded : Icons.payment_rounded,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEditing ? 'Edit Payment' : 'Add Payment',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    splashRadius: 20,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Order Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Order Total:'),
                        Text(
                          '₫${_formatCurrency(widget.totalAmount)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (widget.alreadyPaidAmount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Already Paid:'),
                          Text(
                            '₫${_formatCurrency(widget.alreadyPaidAmount)}',
                            style: TextStyle(color: Colors.green.shade600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Remaining:'),
                          Text(
                            '₫${_formatCurrency(remainingAmount)}',
                            style: TextStyle(
                              color: remainingAmount > 0 ? Colors.orange.shade600 : Colors.green.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Payment Method Selection
              PaymentMethodSelector(
                selectedMethod: _selectedMethod,
                onMethodSelected: (method) {
                  setState(() => _selectedMethod = method);
                },
              ),
              const SizedBox(height: 24),

              // Payment Status
              Text(
                'Payment Status',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: PaymentStatus.values.map((status) {
                  final isSelected = _selectedStatus == status;
                  return InkWell(
                    onTap: () => setState(() => _selectedStatus = status),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade300,
                        ),
                        color: isSelected
                            ? Theme.of(context).primaryColor.withOpacity(0.1)
                            : Colors.transparent,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(status.icon, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            status.displayName,
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
              const SizedBox(height: 24),

              // Amount Input
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (VND)',
                  prefixText: '₫',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter payment amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Transaction ID (optional)
              TextFormField(
                controller: _transactionIdController,
                decoration: const InputDecoration(
                  labelText: 'Transaction ID (Optional)',
                  hintText: 'e.g., bank reference number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Notes (optional)
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'Additional payment details',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isEditing ? 'Update Payment' : 'Add Payment'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}