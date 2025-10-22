import 'package:flutter/material.dart';
import 'services/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('Resetting database...');
  final databaseHelper = DatabaseHelper();
  await databaseHelper.deleteDatabase();
  print('Database reset complete!');

  print('Recreating database with sample data...');
  await databaseHelper.database; // This will trigger database creation
  print('Database recreated with sample data!');
}