import 'package:flutter/material.dart';
import '../../../models/payment_method.dart';
import '../../../models/order.dart';

class PaymentMethodSelector extends StatelessWidget {
  final PaymentMethodType? selectedMethod;
  final Function(PaymentMethodType) onMethodSelected;
  final bool showLabels;

  const PaymentMethodSelector({
    super.key,
    this.selectedMethod,
    required this.onMethodSelected,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabels)
          Text(
            'Payment Method',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        if (showLabels) const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: PaymentMethodType.values.map((method) {
            final isSelected = selectedMethod == method;
            return InkWell(
              onTap: () => onMethodSelected(method),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  color: isSelected
                      ? Theme.of(context).primaryColor.withOpacity(0.1)
                      : Colors.transparent,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      method.icon,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      method.displayName,
                      style: TextStyle(
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
    );
  }
}

class PaymentStatusChip extends StatelessWidget {
  final PaymentStatus status;
  final double? amount;
  final String currency;

  const PaymentStatusChip({
    super.key,
    required this.status,
    this.amount,
    this.currency = 'VND',
  });

  @override
  Widget build(BuildContext context) {
    Color chipColor;
    switch (status) {
      case PaymentStatus.paid:
        chipColor = Colors.green;
        break;
      case PaymentStatus.pending:
        chipColor = Colors.orange;
        break;
      case PaymentStatus.failed:
        chipColor = Colors.red;
        break;
      case PaymentStatus.refunded:
        chipColor = Colors.blue;
        break;
      case PaymentStatus.partiallyPaid:
        chipColor = Colors.amber;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            status.icon,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 6),
          Text(
            status.displayName,
            style: TextStyle(
              color: chipColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          if (amount != null) ...[
            const SizedBox(width: 4),
            Text(
              '• ${_formatCurrency(amount!, currency)}',
              style: TextStyle(
                color: chipColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatCurrency(double amount, String currency) {
    if (currency == 'VND') {
      return '₫${amount.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      )}';
    }
    return '$currency ${amount.toStringAsFixed(2)}';
  }
}

class PaymentMethodDisplay extends StatelessWidget {
  final PaymentMethodType method;
  final PaymentStatus status;
  final double? amount;
  final String? transactionId;
  final DateTime? paymentTime;
  final String currency;
  final bool compact;

  const PaymentMethodDisplay({
    super.key,
    required this.method,
    required this.status,
    this.amount,
    this.transactionId,
    this.paymentTime,
    this.currency = 'VND',
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(method.icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            method.displayName,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          PaymentStatusChip(status: status, amount: amount, currency: currency),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  method.icon,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    if (amount != null)
                      Text(
                        _formatCurrency(amount!, currency),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
              PaymentStatusChip(status: status),
            ],
          ),
          if (transactionId != null || paymentTime != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            if (transactionId != null)
              Row(
                children: [
                  Icon(Icons.receipt_long, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'Transaction ID: $transactionId',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            if (paymentTime != null) ...[
              if (transactionId != null) const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'Paid: ${_formatDateTime(paymentTime!)}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _formatCurrency(double amount, String currency) {
    if (currency == 'VND') {
      return '₫${amount.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      )}';
    }
    return '$currency ${amount.toStringAsFixed(2)}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}