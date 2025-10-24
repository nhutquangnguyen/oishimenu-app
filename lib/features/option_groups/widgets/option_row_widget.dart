import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../models/menu_options.dart';
import '../utils/currency_formatter.dart';

/// Widget for displaying an individual option in the editor
/// Shows option name, price, and allows edit/delete actions
class OptionRowWidget extends StatelessWidget {
  final MenuOption option;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String? validationError;

  const OptionRowWidget({
    super.key,
    required this.option,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    this.validationError,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = validationError != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasError ? Colors.red : Colors.grey[300]!,
          width: hasError ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Drag handle
                  Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.drag_handle,
                      size: 16,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Option content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option.name.isEmpty ? 'Tùy chọn ${index + 1}' : option.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: option.name.isEmpty ? Colors.grey[500] : null,
                          ),
                        ),
                        if (option.description?.isNotEmpty == true)
                          Text(
                            option.description!,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Price badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: option.price > 0
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      option.price.toOptionPrice(),
                      style: TextStyle(
                        color: option.price > 0
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Actions
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleAction(value),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit, size: 16),
                            const SizedBox(width: 8),
                            Text('option_row.edit_button'.tr()),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'duplicate',
                        child: Row(
                          children: [
                            const Icon(Icons.copy, size: 16),
                            const SizedBox(width: 8),
                            Text('option_row.duplicate_button'.tr()),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete, size: 16, color: Colors.red),
                            const SizedBox(width: 8),
                            Text('option_row.delete_button'.tr(), style: const TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.all(4),
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
          ),
          // Error message
          if (hasError)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      validationError!,
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _handleAction(String action) {
    switch (action) {
      case 'edit':
        onEdit();
        break;
      case 'duplicate':
        // TODO: Implement duplicate functionality
        break;
      case 'delete':
        onDelete();
        break;
    }
  }
}