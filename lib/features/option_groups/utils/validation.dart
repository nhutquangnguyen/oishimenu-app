import '../../../models/menu_options.dart';

/// Validation utilities for option groups following the specification requirements
class OptionGroupValidation {
  /// Validation result with error codes and messages
  static const String nameRequired = 'NAME_REQUIRED';
  static const String nameLength = 'NAME_LENGTH_INVALID';
  static const String optionsEmpty = 'OPTIONS_EMPTY';
  static const String duplicateOptionLabel = 'DUPLICATE_OPTION_LABEL';
  static const String optionLabelRequired = 'OPTION_LABEL_REQUIRED';
  static const String optionLabelLength = 'OPTION_LABEL_LENGTH_INVALID';
  static const String priceInvalid = 'PRICE_INVALID';
  static const String selectionConflict = 'SELECTION_CONFLICT_MIN_MAX';
  static const String duplicateGroupName = 'DUPLICATE_GROUP_NAME';
  static const String defaultExceedsMax = 'DEFAULT_EXCEEDS_MAX';
  static const String currencyMismatch = 'CURRENCY_MISMATCH';

  /// Validate option group according to business rules
  static ValidationResult validateOptionGroup(OptionGroup group) {
    final errors = <String, String>{};

    // 1. Group must have name.default and 1-80 characters
    if (group.name.trim().isEmpty) {
      errors['name'] = nameRequired;
    } else if (group.name.trim().length > 80) {
      errors['name'] = nameLength;
    }

    // 2. Group must have at least 1 option
    if (group.options.isEmpty) {
      errors['options'] = optionsEmpty;
    } else {
      // 3. Validate individual options
      final optionValidation = validateOptions(group.options);
      errors.addAll(optionValidation.errors);

      // 4. Check for duplicate option labels (case-insensitive)
      final duplicates = findDuplicateOptionLabels(group.options);
      if (duplicates.isNotEmpty) {
        errors['options'] = '$duplicateOptionLabel: ${duplicates.join(', ')}';
      }
    }

    // 5. Validate selection rules
    final selectionValidation = validateSelectionRules(group);
    errors.addAll(selectionValidation.errors);

    // 6. Validate default selections
    final defaultValidation = validateDefaultSelections(group);
    errors.addAll(defaultValidation.errors);

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Validate individual menu options
  static ValidationResult validateOptions(List<MenuOption> options) {
    final errors = <String, String>{};

    for (int i = 0; i < options.length; i++) {
      final option = options[i];
      final prefix = 'option_$i';

      // Label required (1-60 characters)
      if (option.name.trim().isEmpty) {
        errors['${prefix}_name'] = optionLabelRequired;
      } else if (option.name.trim().length > 60) {
        errors['${prefix}_name'] = optionLabelLength;
      }

      // Price must be >= 0
      if (option.price < 0) {
        errors['${prefix}_price'] = priceInvalid;
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Find duplicate option labels (case-insensitive)
  static List<String> findDuplicateOptionLabels(List<MenuOption> options) {
    final seen = <String>{};
    final duplicates = <String>{};

    for (final option in options) {
      final normalizedLabel = option.name.trim().toLowerCase();
      if (seen.contains(normalizedLabel)) {
        duplicates.add(option.name.trim());
      } else {
        seen.add(normalizedLabel);
      }
    }

    return duplicates.toList();
  }

  /// Validate selection rules based on business requirements
  static ValidationResult validateSelectionRules(OptionGroup group) {
    final errors = <String, String>{};

    // Determine if multiple selections are allowed
    final allowMultiple = group.maxSelection > 1;
    final isRequired = group.isRequired;

    if (!allowMultiple) {
      // Single-select mode
      if (isRequired) {
        // Must select exactly 1
        if (group.minSelection != 1 || group.maxSelection != 1) {
          errors['selection'] = selectionConflict;
        }
      } else {
        // Can select 0 or 1
        if (group.minSelection != 0 || group.maxSelection != 1) {
          errors['selection'] = selectionConflict;
        }
      }
    } else {
      // Multi-select mode
      if (isRequired) {
        // minSelection must be >= 1
        if (group.minSelection < 1) {
          errors['selection'] = selectionConflict;
        }
      } else {
        // minSelection must be 0
        if (group.minSelection != 0) {
          errors['selection'] = selectionConflict;
        }
      }

      // maxSelection must be <= option count and >= minSelection
      if (group.maxSelection > group.options.length) {
        errors['selection'] = 'MAX_EXCEEDS_OPTION_COUNT';
      }

      if (group.maxSelection < group.minSelection) {
        errors['selection'] = selectionConflict;
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Validate default selections against maxSelection rules
  static ValidationResult validateDefaultSelections(OptionGroup group) {
    final errors = <String, String>{};

    // Note: The current MenuOption model doesn't have isDefault field
    // This is a placeholder for when that functionality is added
    // For now, we'll skip this validation

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Check if option group name is unique (would need service call)
  static bool isGroupNameUnique(String name, List<OptionGroup> existingGroups, {String? excludeId}) {
    return !existingGroups.any((group) =>
        group.name.trim().toLowerCase() == name.trim().toLowerCase() &&
        group.id != excludeId);
  }

  /// Get user-friendly error messages
  static String getErrorMessage(String errorCode) {
    switch (errorCode) {
      case nameRequired:
        return 'Tên nhóm là bắt buộc';
      case nameLength:
        return 'Tên nhóm phải từ 1-80 ký tự';
      case optionsEmpty:
        return 'Phải có ít nhất 1 tùy chọn';
      case duplicateOptionLabel:
        return 'Tên tùy chọn không được trùng lặp';
      case duplicateGroupName:
        return 'Tên nhóm tùy chọn đã tồn tại';
      case optionLabelRequired:
        return 'Tên tùy chọn là bắt buộc';
      case optionLabelLength:
        return 'Tên tùy chọn phải từ 1-60 ký tự';
      case priceInvalid:
        return 'Giá phải lớn hơn hoặc bằng 0';
      case selectionConflict:
        return 'Cài đặt lựa chọn không hợp lệ';
      case defaultExceedsMax:
        return 'Số lượng mặc định vượt quá giới hạn tối đa';
      case currencyMismatch:
        return 'Loại tiền tệ không khớp';
      default:
        return 'Lỗi không xác định';
    }
  }

  /// Compute selection rules automatically based on settings
  static SelectionRules computeSelectionRules({
    required bool isRequired,
    required bool allowMultiple,
    required int optionCount,
    int? maxSelections,
  }) {
    if (!allowMultiple) {
      // Single-select mode
      return SelectionRules(
        min: isRequired ? 1 : 0,
        max: 1,
      );
    } else {
      // Multi-select mode
      final maxCount = maxSelections ?? optionCount;
      // Don't clamp to optionCount - allow setting higher max for future options
      // Just ensure it's at least 2 for multiple selection mode
      return SelectionRules(
        min: isRequired ? 1 : 0,
        max: maxCount < 2 ? 2 : maxCount,
      );
    }
  }
}

/// Validation result container
class ValidationResult {
  final bool isValid;
  final Map<String, String> errors;

  ValidationResult({
    required this.isValid,
    required this.errors,
  });

  String? getFieldError(String fieldName) => errors[fieldName];
  bool hasFieldError(String fieldName) => errors.containsKey(fieldName);
}

/// Selection rules container
class SelectionRules {
  final int min;
  final int max;

  SelectionRules({
    required this.min,
    required this.max,
  });

  @override
  String toString() {
    if (min == 0 && max == 1) {
      return 'Tùy chọn, chọn tối đa 1';
    } else if (min == 1 && max == 1) {
      return 'Bắt buộc, chọn đúng 1';
    } else if (min == 0) {
      return 'Tùy chọn, chọn tối đa $max';
    } else if (min == max) {
      return 'Bắt buộc, chọn đúng $min';
    } else {
      return 'Chọn từ $min đến $max';
    }
  }
}