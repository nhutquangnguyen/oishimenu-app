import 'package:flutter/material.dart';

class FeedbackPage extends StatelessWidget {
  const FeedbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.feedback, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Customer Feedback',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'View and respond to customer reviews',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}