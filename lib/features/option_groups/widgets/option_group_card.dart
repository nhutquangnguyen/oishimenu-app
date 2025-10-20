import 'package:flutter/material.dart';
import '../../../models/menu_options.dart';
import '../utils/currency_formatter.dart';
import '../utils/validation.dart';

/// Card widget for displaying an option group in the list
/// Shows key information and allows quick actions
class OptionGroupCard extends StatelessWidget {
  final OptionGroup optionGroup;
  final VoidCallback onTap;
  final ValueChanged<bool>? onToggleRequired;
  final VoidCallback? onDelete;
  final bool showOptions;

  const OptionGroupCard({
    super.key,
    required this.optionGroup,
    required this.onTap,
    this.onToggleRequired,
    this.onDelete,
    this.showOptions = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectionRules = OptionGroupValidation.computeSelectionRules(
      isRequired: optionGroup.isRequired,
      allowMultiple: optionGroup.maxSelection > 1,
      optionCount: optionGroup.options.length,
      maxSelections: optionGroup.maxSelection,
    );

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Group name and badges
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                optionGroup.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (optionGroup.isRequired)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                margin: const EdgeInsets.only(left: 8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'BẮT BUỘC',
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Selection rules and option count
                        Text(
                          '${optionGroup.options.length} tùy chọn • ${selectionRules.toString()}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        // Description if available
                        if (optionGroup.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            optionGroup.description!,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        // Price range
                        if (optionGroup.options.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _buildPriceRangeText(),
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Action buttons
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleMenuAction(context, value),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 16),
                            SizedBox(width: 8),
                            Text('Chỉnh sửa'),
                          ],
                        ),
                      ),
                      if (onToggleRequired != null)
                        PopupMenuItem(
                          value: 'toggle_required',
                          child: Row(
                            children: [
                              Icon(
                                optionGroup.isRequired
                                    ? Icons.toggle_on
                                    : Icons.toggle_off,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(optionGroup.isRequired
                                  ? 'Đặt thành tùy chọn'
                                  : 'Đặt thành bắt buộc'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: Row(
                          children: [
                            Icon(Icons.copy, size: 16),
                            SizedBox(width: 8),
                            Text('Nhân bản'),
                          ],
                        ),
                      ),
                      if (onDelete != null) ...[
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 16, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Xóa', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ],
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.more_vert,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Options preview (if enabled)
            if (showOptions && optionGroup.options.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: Column(
                  children: optionGroup.options.take(3).map((option) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            optionGroup.maxSelection > 1
                                ? Icons.check_box_outline_blank
                                : Icons.radio_button_unchecked,
                            size: 16,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option.name,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          if (option.price > 0)
                            Text(
                              option.price.toOptionPrice(),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            // Show more indicator
            if (showOptions && optionGroup.options.length > 3)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: Center(
                  child: Text(
                    '+${optionGroup.options.length - 3} tùy chọn khác',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _buildPriceRangeText() {
    if (optionGroup.options.isEmpty) {
      return 'Chưa có tùy chọn';
    }

    final prices = optionGroup.options.map((option) => option.price).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);

    if (minPrice == maxPrice) {
      if (minPrice == 0) {
        return 'Miễn phí';
      } else {
        return 'Giá: +${minPrice.toVND()}';
      }
    } else {
      return 'Giá: ${CurrencyFormatter.formatPriceRange(minPrice, maxPrice)}';
    }
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'edit':
        onTap();
        break;
      case 'toggle_required':
        onToggleRequired?.call(!optionGroup.isRequired);
        break;
      case 'duplicate':
        _showDuplicateSnackbar(context);
        break;
      case 'delete':
        onDelete?.call();
        break;
    }
  }

  void _showDuplicateSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Nhân bản "${optionGroup.name}" - Coming soon!'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}