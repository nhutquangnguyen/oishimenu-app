import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../models/menu_options.dart';
import '../utils/currency_formatter.dart';
import '../utils/validation.dart';

/// Widget that shows a live preview of how the option group will appear to customers
/// Renders the actual UI that customers will see when ordering
class PreviewCardWidget extends StatefulWidget {
  final String groupName;
  final List<MenuOption> options;
  final bool isRequired;
  final bool allowMultiple;
  final int minSelections;
  final int maxSelections;

  const PreviewCardWidget({
    super.key,
    required this.groupName,
    required this.options,
    required this.isRequired,
    required this.allowMultiple,
    required this.minSelections,
    required this.maxSelections,
  });

  @override
  State<PreviewCardWidget> createState() => _PreviewCardWidgetState();
}

class _PreviewCardWidgetState extends State<PreviewCardWidget> {
  final Set<String> _selectedOptions = {};

  @override
  Widget build(BuildContext context) {
    if (widget.groupName.trim().isEmpty && widget.options.isEmpty) {
      return _buildEmptyPreview();
    }

    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (widget.options.isNotEmpty) _buildOptionsList(),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildEmptyPreview() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.preview,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'preview_card.empty_title'.tr(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'preview_card.empty_subtitle'.tr(),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final selectionRules = OptionGroupValidation.computeSelectionRules(
      isRequired: widget.isRequired,
      allowMultiple: widget.allowMultiple,
      optionCount: widget.options.length,
      maxSelections: widget.maxSelections,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.groupName.trim().isEmpty ? 'preview_card.group_name_placeholder'.tr() : widget.groupName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: widget.groupName.trim().isEmpty ? Colors.grey[400] : null,
                  ),
                ),
              ),
              if (widget.isRequired)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'preview_card.required_badge'.tr(),
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
          Text(
            selectionRules.toString(),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsList() {
    if (widget.options.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            'preview_card.no_options'.tr(),
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Column(
      children: widget.options.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final isSelected = _selectedOptions.contains(option.id.isEmpty ? 'temp_$index' : option.id);

        return Container(
          decoration: BoxDecoration(
            border: Border(
              top: index == 0 ? BorderSide(color: Colors.grey[300]!) : BorderSide.none,
              bottom: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: InkWell(
            onTap: () => _toggleOption(option.id.isEmpty ? 'temp_$index' : option.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Selection indicator
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[400]!,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(widget.allowMultiple ? 4 : 10),
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                    ),
                    child: isSelected
                        ? Icon(
                            widget.allowMultiple ? Icons.check : Icons.circle,
                            size: 12,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  // Option content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option.name.isEmpty ? 'preview_card.option_placeholder'.tr(namedArgs: {'number': (index + 1).toString()}) : option.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: option.name.isEmpty ? Colors.grey[400] : null,
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
                  // Price
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
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFooter() {
    final selectedCount = _selectedOptions.length;
    final validationMessage = _getValidationMessage();

    if (validationMessage == null && selectedCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: validationMessage != null ? Colors.red.withValues(alpha: 0.1) : Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          Icon(
            validationMessage != null ? Icons.error_outline : Icons.info_outline,
            size: 16,
            color: validationMessage != null ? Colors.red[700] : Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              validationMessage ?? 'preview_card.selected_count'.tr(namedArgs: {'selected': selectedCount.toString(), 'max': widget.maxSelections.toString()}),
              style: TextStyle(
                color: validationMessage != null ? Colors.red[700] : Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleOption(String optionId) {
    setState(() {
      if (widget.allowMultiple) {
        // Multiple selection mode
        if (_selectedOptions.contains(optionId)) {
          _selectedOptions.remove(optionId);
        } else if (_selectedOptions.length < widget.maxSelections) {
          _selectedOptions.add(optionId);
        }
      } else {
        // Single selection mode
        if (_selectedOptions.contains(optionId)) {
          _selectedOptions.clear();
        } else {
          _selectedOptions.clear();
          _selectedOptions.add(optionId);
        }
      }
    });
  }

  String? _getValidationMessage() {
    final selectedCount = _selectedOptions.length;

    if (widget.isRequired && selectedCount < widget.minSelections) {
      if (widget.minSelections == 1) {
        return 'preview_card.validation_min_one'.tr();
      } else {
        return 'preview_card.validation_min'.tr(namedArgs: {'min': widget.minSelections.toString()});
      }
    }

    if (selectedCount > widget.maxSelections) {
      return 'preview_card.validation_max'.tr(namedArgs: {'max': widget.maxSelections.toString()});
    }

    return null;
  }
}