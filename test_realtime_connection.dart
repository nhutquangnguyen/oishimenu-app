import 'package:flutter/material.dart';
import 'lib/services/supabase_service.dart';

/// Test widget to verify Supabase real-time connection
class RealtimeTestWidget extends StatefulWidget {
  const RealtimeTestWidget({Key? key}) : super(key: key);

  @override
  State<RealtimeTestWidget> createState() => _RealtimeTestWidgetState();
}

class _RealtimeTestWidgetState extends State<RealtimeTestWidget> {
  final List<String> _logs = [];
  late final Stream<List<Map<String, dynamic>>> _ordersStream;

  @override
  void initState() {
    super.initState();
    _setupRealtimeTest();
  }

  void _setupRealtimeTest() {
    print('🧪 [REALTIME TEST] Setting up real-time test...');

    // Create a real-time stream to monitor orders table
    _ordersStream = SupabaseService.client
        .from('orders')
        .stream(primaryKey: ['id']);

    // Listen to the stream and log all changes
    _ordersStream.listen((data) {
      final timestamp = DateTime.now().toString().substring(11, 19);
      final message = '[$timestamp] Real-time update: ${data.length} orders';

      setState(() {
        _logs.add(message);
        // Keep only last 20 logs
        if (_logs.length > 20) {
          _logs.removeAt(0);
        }
      });

      print('🧪 [REALTIME TEST] $message');
    });

    _addLog('Real-time test initialized');
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    setState(() {
      _logs.add('[$timestamp] $message');
      if (_logs.length > 20) {
        _logs.removeAt(0);
      }
    });
  }

  void _testConnection() {
    _addLog('Testing connection...');
    print('🧪 [REALTIME TEST] Manual connection test triggered');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-time Connection Test'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Connection status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Real-time Connection Status',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Listening to orders table changes...'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _testConnection,
                  child: const Text('Test Connection'),
                ),
              ],
            ),
          ),

          // Logs
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Real-time Logs:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _logs.map((log) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              log,
                              style: const TextStyle(
                                color: Colors.green,
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          )).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Instructions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.orange.shade50,
            child: const Text(
              'Instructions:\n'
              '1. Run this on both devices\n'
              '2. Cancel an order on one device\n'
              '3. Watch if both devices receive real-time updates\n'
              '4. Both should show the same log entries',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}