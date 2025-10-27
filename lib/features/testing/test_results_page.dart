import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/automated_test_service.dart';

/// Test results page that shows comprehensive testing results
class TestResultsPage extends ConsumerStatefulWidget {
  const TestResultsPage({super.key});

  @override
  ConsumerState<TestResultsPage> createState() => _TestResultsPageState();
}

class _TestResultsPageState extends ConsumerState<TestResultsPage> {
  final AutomatedTestService _testService = AutomatedTestService();
  TestSummary? _testSummary;
  bool _isRunning = false;
  final List<TestResult> _currentResults = [];

  @override
  void initState() {
    super.initState();
    _startTests();
  }

  Future<void> _startTests() async {
    setState(() {
      _isRunning = true;
      _currentResults.clear();
    });

    // Listen to test results stream
    _testService.results.listen((result) {
      if (mounted) {
        setState(() {
          _currentResults.add(result);
        });
      }
    });

    try {
      final summary = await _testService.runAllTests(ref);
      if (mounted) {
        setState(() {
          _testSummary = summary;
          _isRunning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test execution failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _testService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('🧪 Automated Test Results'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          if (!_isRunning)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _startTests,
              tooltip: 'Run Tests Again',
            ),
        ],
      ),
      body: Column(
        children: [
          // Header with summary
          _buildTestHeader(),

          // Progress indicator
          if (_isRunning) _buildProgressIndicator(),

          // Test results list
          Expanded(
            child: _buildTestResultsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTestHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'OishiMenu App Testing',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (_testSummary != null) ...[
              Text(
                _testSummary!.summary,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildStatusChip('Passed', _testSummary!.passedTests, Colors.green),
                  const SizedBox(width: 8),
                  _buildStatusChip('Failed', _testSummary!.failedTests, Colors.red),
                  const SizedBox(width: 8),
                  _buildStatusChip('Skipped', _testSummary!.skippedTests, Colors.orange),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _testSummary!.successRate,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _testSummary!.successRate > 0.8 ? Colors.green :
                    _testSummary!.successRate > 0.6 ? Colors.orange : Colors.red,
                  ),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Success Rate: ${(_testSummary!.successRate * 100).toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ] else if (_isRunning) ...[
              Text(
                'Running comprehensive tests...',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tests completed: ${_currentResults.length}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ] else ...[
              Text(
                'Ready to run automated tests',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $count',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: _testService.progress,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Running tests... ${(_testService.progress * 100).toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestResultsList() {
    final results = _testSummary?.results ?? _currentResults;

    if (results.isEmpty && !_isRunning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.science_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No test results yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the refresh button to run tests',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.assignment_turned_in,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Test Results',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_isRunning)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: results.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final result = results[index];
                return _buildTestResultCard(result);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestResultCard(TestResult result) {
    final isSuccess = result.status == TestStatus.passed;
    final isFailure = result.status == TestStatus.failed;
    final isSkipped = result.status == TestStatus.skipped;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSuccess ? Colors.green.withOpacity(0.1) :
               isFailure ? Colors.red.withOpacity(0.1) :
               Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSuccess ? Colors.green.withOpacity(0.3) :
                 isFailure ? Colors.red.withOpacity(0.3) :
                 Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isSuccess ? Colors.green :
                     isFailure ? Colors.red :
                     Colors.orange,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSuccess ? Icons.check :
              isFailure ? Icons.close :
              Icons.remove,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      result.testId,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSuccess ? Colors.green[700] :
                               isFailure ? Colors.red[700] :
                               Colors.orange[700],
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('HH:mm:ss').format(result.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  result.message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}