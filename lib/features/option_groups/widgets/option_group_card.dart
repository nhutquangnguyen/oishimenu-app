import 'package:flutter/material.dart';
import '../../../models/menu_options.dart';
import '../utils/currency_formatter.dart';
import '../utils/validation.dart';

/// Card widget for displaying an option group in the list
/// Shows key information and navigates to edit page when tapped
class OptionGroupCard extends StatelessWidget {
  final OptionGroup optionGroup;
  final VoidCallback onTap;

  const OptionGroupCard({
    super.key,
    required this.optionGroup,
    required this.onTap,
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
        child: Padding(
          padding: const EdgeInsets.all(16),
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

}