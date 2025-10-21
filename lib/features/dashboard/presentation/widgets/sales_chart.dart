import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SalesChart extends StatelessWidget {
  final String timeFrame;

  const SalesChart({super.key, required this.timeFrame});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawHorizontalLine: true,
                    drawVerticalLine: false,
                    horizontalInterval: 500000,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey[300],
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              _getBottomTitle(value.toInt()),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 500000,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          return Text(
                            '${(value / 1000000).toStringAsFixed(1)}M',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        },
                        reservedSize: 42,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: false,
                  ),
                  minX: 0,
                  maxX: _getMaxX(),
                  minY: 0,
                  maxY: _getMaxY(),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _getChartData(),
                      isCurved: true,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6d28d9), Color(0xFF7c3aed)],
                      ),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.white,
                            strokeWidth: 2,
                            strokeColor: const Color(0xFF6d28d9),
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF6d28d9).withOpacity(0.1),
                            const Color(0xFF7c3aed).withOpacity(0.05),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _getChartData() {
    switch (timeFrame) {
      case 'Today':
        // Hourly data for today (24 hours, showing every 3 hours)
        return const [
          FlSpot(0, 120000),   // 6 AM
          FlSpot(1, 350000),   // 9 AM
          FlSpot(2, 580000),   // 12 PM
          FlSpot(3, 820000),   // 3 PM
          FlSpot(4, 1200000),  // 6 PM
          FlSpot(5, 1850000),  // 9 PM
          FlSpot(6, 2450000),  // 12 AM
        ];
      case 'This Week':
        // Daily data for this week
        return const [
          FlSpot(0, 1800000),  // Monday
          FlSpot(1, 2100000),  // Tuesday
          FlSpot(2, 1650000),  // Wednesday
          FlSpot(3, 2400000),  // Thursday
          FlSpot(4, 2800000),  // Friday
          FlSpot(5, 2200000),  // Saturday
          FlSpot(6, 2450000),  // Sunday
        ];
      case 'This Month':
        // Weekly data for this month (4 weeks)
        return const [
          FlSpot(0, 8200000),  // Week 1
          FlSpot(1, 12300000), // Week 2
          FlSpot(2, 15100000), // Week 3
          FlSpot(3, 22400000), // Week 4
        ];
      case 'Last 30 Days':
        // Weekly data for last 30 days
        return const [
          FlSpot(0, 7800000),  // Week 1
          FlSpot(1, 13200000), // Week 2
          FlSpot(2, 18500000), // Week 3
          FlSpot(3, 21700000), // Week 4
        ];
      default:
        return const [FlSpot(0, 0)];
    }
  }

  double _getMaxX() {
    switch (timeFrame) {
      case 'Today':
        return 6; // 7 data points (0-6)
      case 'This Week':
        return 6; // 7 days (0-6)
      case 'This Month':
      case 'Last 30 Days':
        return 3; // 4 weeks (0-3)
      default:
        return 6;
    }
  }

  double _getMaxY() {
    switch (timeFrame) {
      case 'Today':
        return 3000000; // 3M VND
      case 'This Week':
        return 3000000; // 3M VND
      case 'This Month':
      case 'Last 30 Days':
        return 25000000; // 25M VND
      default:
        return 3000000;
    }
  }

  String _getBottomTitle(int value) {
    switch (timeFrame) {
      case 'Today':
        // Hour labels
        switch (value) {
          case 0: return '6AM';
          case 1: return '9AM';
          case 2: return '12PM';
          case 3: return '3PM';
          case 4: return '6PM';
          case 5: return '9PM';
          case 6: return '12AM';
          default: return '';
        }
      case 'This Week':
        // Day labels
        switch (value) {
          case 0: return 'Mon';
          case 1: return 'Tue';
          case 2: return 'Wed';
          case 3: return 'Thu';
          case 4: return 'Fri';
          case 5: return 'Sat';
          case 6: return 'Sun';
          default: return '';
        }
      case 'This Month':
      case 'Last 30 Days':
        // Week labels
        switch (value) {
          case 0: return 'W1';
          case 1: return 'W2';
          case 2: return 'W3';
          case 3: return 'W4';
          default: return '';
        }
      default:
        return '';
    }
  }
}