import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Widget for configuring option group selection rules
/// Handles required/optional, single/multi selection, min/max counts
class SelectionRulesWidget extends StatelessWidget {
  final bool isRequired;
  final bool allowMultiple;
  final int minSelections;
  final int maxSelections;
  final int optionCount;
  final ValueChanged<bool> onRequiredChanged;
  final ValueChanged<bool> onAllowMultipleChanged;
  final ValueChanged<int> onMinSelectionsChanged;
  final ValueChanged<int> onMaxSelectionsChanged;

  const SelectionRulesWidget({
    super.key,
    required this.isRequired,
    required this.allowMultiple,
    required this.minSelections,
    required this.maxSelections,
    required this.optionCount,
    required this.onRequiredChanged,
    required this.onAllowMultipleChanged,
    required this.onMinSelectionsChanged,
    required this.onMaxSelectionsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'selection_rules.title'.tr(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Make mandatory switch
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'selection_rules.required_title'.tr(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'selection_rules.required_subtitle'.tr(),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isRequired,
                    onChanged: onRequiredChanged,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Allow multiple switch
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'selection_rules.allow_multiple_title'.tr(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'selection_rules.allow_multiple_subtitle'.tr(),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: allowMultiple,
                    onChanged: onAllowMultipleChanged,
                  ),
                ],
              ),

              // Selection limits (only show when multiple selection is enabled)
              if (allowMultiple) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // Max selections
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'selection_rules.max_title'.tr(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'selection_rules.max_subtitle'.tr(),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStepper(
                      value: maxSelections,
                      min: 1,
                      max: optionCount > 0 ? optionCount : 10,
                      onChanged: onMaxSelectionsChanged,
                    ),
                  ],
                ),

                // Min selections (only show when required)
                if (isRequired) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'selection_rules.min_title'.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'selection_rules.min_subtitle'.tr(),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStepper(
                        value: minSelections,
                        min: 1,
                        max: maxSelections,
                        onChanged: onMinSelectionsChanged,
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Selection summary
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _buildSelectionSummary(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepper({
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove, size: 16),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              value.toString(),
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ),
          IconButton(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add, size: 16),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  String _buildSelectionSummary() {
    if (!allowMultiple) {
      if (isRequired) {
        return 'selection_rules.summary_single_required'.tr();
      } else {
        return 'selection_rules.summary_single_optional'.tr();
      }
    } else {
      if (isRequired) {
        if (minSelections == maxSelections) {
          return 'selection_rules.summary_exact'.tr(namedArgs: {'count': minSelections.toString()});
        } else {
          return 'selection_rules.summary_range'.tr(namedArgs: {'min': minSelections.toString(), 'max': maxSelections.toString()});
        }
      } else {
        return 'selection_rules.summary_max_optional'.tr(namedArgs: {'max': maxSelections.toString()});
      }
    }
  }
}