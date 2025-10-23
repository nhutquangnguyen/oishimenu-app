import 'database_helper.dart';
import '../models/customer.dart';

class CustomerService {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  /// Get all customers
  Future<List<Customer>> getAllCustomers() async {
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'customers',
        orderBy: 'created_at DESC',
      );

      return List.generate(maps.length, (i) {
        return Customer.fromMap(maps[i]);
      });
    } catch (e) {
      print('Error fetching customers: $e');
      return [];
    }
  }

  /// Search customer by phone number
  Future<Customer?> getCustomerByPhone(String phone) async {
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'customers',
        where: 'phone = ?',
        whereArgs: [phone],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return Customer.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      print('Error fetching customer by phone: $e');
      return null;
    }
  }

  /// Create a new customer (phone can be optional, but if provided, must be unique)
  Future<String?> createCustomer(Customer customer) async {
    try {
      final db = await _databaseHelper.database;

      // Check if phone already exists (only if phone is provided)
      if (customer.phone != null && customer.phone!.isNotEmpty) {
        final existing = await getCustomerByPhone(customer.phone!);
        if (existing != null) {
          throw Exception('Customer with phone "${customer.phone}" already exists');
        }
      }

      final id = await db.insert('customers', customer.toMap());
      return id.toString();
    } catch (e) {
      print('Error creating customer: $e');
      return null;
    }
  }

  /// Update customer information
  Future<bool> updateCustomer(Customer customer) async {
    try {
      final db = await _databaseHelper.database;

      // Check for duplicate phone (excluding current customer, only if phone is provided)
      if (customer.phone != null && customer.phone!.isNotEmpty) {
        final existing = await db.query(
          'customers',
          where: 'phone = ? AND id != ?',
          whereArgs: [customer.phone, int.tryParse(customer.id)],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          throw Exception('Customer with phone "${customer.phone}" already exists');
        }
      }

      final rowsAffected = await db.update(
        'customers',
        customer.toMap(),
        where: 'id = ?',
        whereArgs: [int.tryParse(customer.id)],
      );

      return rowsAffected > 0;
    } catch (e) {
      print('Error updating customer: $e');
      return false;
    }
  }

  /// Delete a customer
  Future<bool> deleteCustomer(String customerId) async {
    try {
      final db = await _databaseHelper.database;
      final rowsAffected = await db.delete(
        'customers',
        where: 'id = ?',
        whereArgs: [int.tryParse(customerId)],
      );

      return rowsAffected > 0;
    } catch (e) {
      print('Error deleting customer: $e');
      return false;
    }
  }
}
