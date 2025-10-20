import 'package:flutter/material.dart';
import '../../../../models/menu_item.dart';

class MenuItemCard extends StatelessWidget {
  final MenuItem menuItem;
  final String categoryName;
  final VoidCallback? onTap;
  final VoidCallback? onToggleAvailability;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const MenuItemCard({
    super.key,
    required this.menuItem,
    required this.categoryName,
    this.onTap,
    this.onToggleAvailability,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with name and availability
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          menuItem.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: menuItem.availableStatus
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(categoryName).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            categoryName,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: _getCategoryColor(categoryName),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Availability toggle
                  Switch.adaptive(
                    value: menuItem.availableStatus,
                    onChanged: (_) => onToggleAvailability?.call(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Description
              if (menuItem.description?.isNotEmpty == true)
                Text(
                  menuItem.description!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

              const SizedBox(height: 12),

              // Price and actions row
              Row(
                children: [
                  // Price
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '₫${menuItem.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 16,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Action buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onEdit != null)
                        IconButton(
                          onPressed: onEdit,
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          tooltip: 'Edit',
                        ),
                      if (onDelete != null)
                        IconButton(
                          onPressed: onDelete,
                          icon: Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          tooltip: 'Delete',
                        ),
                    ],
                  ),
                ],
              ),

              // Cost price info (for staff/admin)
              if (menuItem.costPrice != null && menuItem.costPrice! > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Cost: ₫${menuItem.costPrice!.toStringAsFixed(2)} • ',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        'Margin: ${((menuItem.price - menuItem.costPrice!) / menuItem.price * 100).toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'appetizers':
        return Colors.orange[600]!;
      case 'main course':
        return Colors.red[600]!;
      case 'desserts':
        return Colors.pink[600]!;
      case 'beverages':
        return Colors.blue[600]!;
      case 'vietnamese specials':
        return Colors.green[600]!;
      default:
        return Colors.grey[600]!;
    }
  }
}