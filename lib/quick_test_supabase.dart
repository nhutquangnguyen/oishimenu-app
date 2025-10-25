import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Quick access widget to test Supabase - can be added anywhere in your app
class QuickSupabaseTestButton extends StatelessWidget {
  const QuickSupabaseTestButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        context.push('/test-supabase');
      },
      backgroundColor: Colors.blue[600],
      foregroundColor: Colors.white,
      icon: const Icon(Icons.cloud),
      label: const Text('Test Supabase'),
    );
  }
}

/// A simple page to quickly navigate to Supabase test
class QuickTestPage extends StatelessWidget {
  const QuickTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Tests'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            const Text(
              'Test Your Supabase Integration',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Verify your cloud database connection',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                context.push('/test-supabase');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text(
                'Run Supabase Tests',
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                context.pop();
              },
              child: const Text('Back to App'),
            ),
          ],
        ),
      ),
    );
  }
}