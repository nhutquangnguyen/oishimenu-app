import 'package:flutter/material.dart';

/// Centralized error message handling to provide user-friendly error messages
/// instead of exposing raw exceptions to users
class ErrorMessages {
  // Network and connectivity errors
  static String get networkError => 'Please check your internet connection and try again.';
  static String get timeoutError => 'Request timed out. Please try again.';
  static String get serverError => 'Server is temporarily unavailable. Please try again later.';

  // Data loading errors
  static String get loadingDataError => 'Unable to load data. Please refresh and try again.';
  static String get loadingFinanceError => 'Unable to load your financial data. Please check your connection and try again.';
  static String get loadingOrdersError => 'Unable to load orders. Please refresh the page.';
  static String get loadingMenuError => 'Unable to load menu items. Please refresh and try again.';
  static String get loadingBestSellersError => 'Unable to load sales data. Please refresh the page.';

  // Saving and creating errors
  static String get savingDataError => 'We couldn\'t save your changes. Please try again.';
  static String get savingFinanceEntryError => 'We couldn\'t save your entry. Please try again.';
  static String get savingOrderError => 'Unable to save the order. Please try again.';
  static String get creatingItemError => 'Unable to create item. Please check your input and try again.';

  // Order operations
  static String get completeOrderError => 'Failed to complete this order. Please try again or contact support if the problem persists.';
  static String get cancelOrderError => 'Could not cancel this order. Please try again.';
  static String get updateOrderError => 'Could not update this order. Please try again.';

  // Cart and POS operations
  static String get emptyCartError => 'Your cart is empty. Add items to create an order.';
  static String get addToCartError => 'Unable to add item to cart. Please try again.';

  // Validation errors
  static String get invalidAmountError => 'Please enter a valid amount greater than 0.';
  static String get requiredFieldError => 'This field is required.';
  static String get descriptionRequiredError => 'Please provide a description for this transaction (e.g., \'Daily sales\', \'Ingredient purchase\').';

  // File and photo operations
  static String get photoUploadError => 'Couldn\'t add this photo. Please try with a different image or check file size.';
  static String get fileOperationError => 'File operation failed. Please try again.';

  // Authentication and permissions
  static String get authError => 'Authentication failed. Please log in again.';
  static String get permissionError => 'You don\'t have permission to perform this action.';

  // Generic fallback
  static String get unknownError => 'Something went wrong. Please try again or contact support if the problem persists.';

  /// Get user-friendly error message based on exception type
  static String getErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('socket')) {
      return networkError;
    }

    if (errorString.contains('timeout')) {
      return timeoutError;
    }

    if (errorString.contains('server') ||
        errorString.contains('500') ||
        errorString.contains('502') ||
        errorString.contains('503')) {
      return serverError;
    }

    if (errorString.contains('auth') ||
        errorString.contains('unauthorized') ||
        errorString.contains('401')) {
      return authError;
    }

    if (errorString.contains('permission') ||
        errorString.contains('forbidden') ||
        errorString.contains('403')) {
      return permissionError;
    }

    // Default fallback
    return unknownError;
  }

  /// Show user-friendly error snackbar
  static void showErrorSnackbar(BuildContext context, dynamic error, {String? customMessage}) {
    final message = customMessage ?? getErrorMessage(error);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}