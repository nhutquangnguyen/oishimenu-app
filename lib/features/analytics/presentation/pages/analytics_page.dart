import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../widgets/analytics_charts.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  String _selectedTimeFrame = 'Today';
  String _selectedBranch = 'All Branches';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.tr('finance') != 'finance'
              ? AppLocalizations.tr('finance')
              : 'Finance & Analytics',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Section
            Row(
              children: [
                // Time Frame Filter
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedTimeFrame,
                      isExpanded: true,
                      underline: const SizedBox(),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      items: [
                        DropdownMenuItem<String>(
                          value: 'Today',
                          child: Text(AppLocalizations.tr('dashboard.today')),
                        ),
                        DropdownMenuItem<String>(
                          value: 'This Week',
                          child: Text(AppLocalizations.tr('dashboard.this_week')),
                        ),
                        DropdownMenuItem<String>(
                          value: 'This Month',
                          child: Text(AppLocalizations.tr('dashboard.this_month')),
                        ),
                        DropdownMenuItem<String>(
                          value: 'Last 30 Days',
                          child: Text(AppLocalizations.tr('dashboard.last_30_days')),
                        ),
                      ],
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedTimeFrame = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Branch Filter
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedBranch,
                      isExpanded: true,
                      underline: const SizedBox(),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      items: [
                        DropdownMenuItem<String>(
                          value: 'All Branches',
                          child: Text(AppLocalizations.tr('dashboard.all_branches')),
                        ),
                        DropdownMenuItem<String>(
                          value: 'Main Branch',
                          child: Text(AppLocalizations.tr('dashboard.main_branch')),
                        ),
                        DropdownMenuItem<String>(
                          value: 'Secondary Branch',
                          child: Text(AppLocalizations.tr('dashboard.secondary_branch')),
                        ),
                      ],
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedBranch = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Analytics Breakdown Section
            Text(
              AppLocalizations.tr('dashboard.analytics_breakdown'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // Analytics Charts
            AnalyticsCharts(
              timeFrame: _selectedTimeFrame,
              branch: _selectedBranch,
            ),
          ],
        ),
      ),
    );
  }
}