import 'package:intl/intl.dart';

/// Vietnamese currency formatting utilities for option group pricing
class CurrencyFormatter {
  static const String vietnameseCurrency = 'VND';
  static const String vietnameseLocale = 'vi-VN';

  /// Format currency amount in Vietnamese Dong
  /// Returns formatted string like "7.000đ" or "0đ"
  static String formatVND(double amount) {
    if (amount == 0) {
      return '0đ';
    }

    // Use Vietnamese locale for number formatting
    final formatter = NumberFormat.currency(
      locale: vietnameseLocale,
      symbol: 'đ',
      decimalDigits: 0,
    );

    return formatter.format(amount);
  }

  /// Format price with plus prefix for option pricing
  /// Returns "+7.000đ" for positive amounts, "0đ" for zero
  static String formatOptionPrice(double price) {
    if (price == 0) {
      return '0đ';
    } else if (price > 0) {
      return '+${formatVND(price)}';
    } else {
      return formatVND(price); // Negative amounts without double minus
    }
  }

  /// Format price range for display (e.g., "0đ - 50.000đ")
  static String formatPriceRange(double minPrice, double maxPrice) {
    if (minPrice == maxPrice) {
      return formatVND(minPrice);
    }
    return '${formatVND(minPrice)} - ${formatVND(maxPrice)}';
  }

  /// Parse Vietnamese formatted currency string back to double
  /// Handles strings like "7.000đ", "+7.000đ", "7000", etc.
  static double parseVND(String formattedAmount) {
    if (formattedAmount.isEmpty) return 0.0;

    // Remove currency symbol, plus sign, and spaces
    String cleanAmount = formattedAmount
        .replaceAll('đ', '')
        .replaceAll('+', '')
        .replaceAll(' ', '')
        .replaceAll('.', ''); // Remove thousand separators

    return double.tryParse(cleanAmount) ?? 0.0;
  }

  /// Check if an amount string is valid Vietnamese currency format
  static bool isValidVNDFormat(String amount) {
    if (amount.isEmpty) return false;

    // Allow formats: "1000", "1.000", "1.000đ", "+1.000đ"
    final RegExp vndPattern = RegExp(r'^[\+]?[\d]{1,3}(\.[\d]{3})*[đ]?$');
    return vndPattern.hasMatch(amount.trim());
  }

  /// Get currency symbol for display
  static String get currencySymbol => 'đ';

  /// Get locale for Vietnamese formatting
  static String get locale => vietnameseLocale;
}

/// Extension on double for convenient currency formatting
extension CurrencyExtension on double {
  /// Format as Vietnamese currency
  String toVND() => CurrencyFormatter.formatVND(this);

  /// Format as option price with plus prefix
  String toOptionPrice() => CurrencyFormatter.formatOptionPrice(this);
}

/// Extension on String for parsing currency
extension CurrencyParsingExtension on String {
  /// Parse Vietnamese currency string to double
  double parseVND() => CurrencyFormatter.parseVND(this);

  /// Check if string is valid VND format
  bool get isValidVND => CurrencyFormatter.isValidVNDFormat(this);
}