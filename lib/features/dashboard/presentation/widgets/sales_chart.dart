import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SalesChart extends StatelessWidget {
  final String timeFrame;
  final String groupBy;

  const SalesChart({
    super.key,
    required this.timeFrame,
    required this.groupBy,
  });

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
                    horizontalInterval: _getYAxisInterval(),
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
                        interval: _getYAxisInterval(),
                        getTitlesWidget: (double value, TitleMeta meta) {
                          if (value == 0) return const Text('');

                          String label;
                          if (value >= 1000000) {
                            label = '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
                          } else if (value >= 1000) {
                            label = '${(value / 1000).toStringAsFixed(0)}K';
                          } else {
                            label = '${value.toStringAsFixed(0)}';
                          }

                          return Text(
                            label,
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
    final baseMultiplier = _getTimeFrameMultiplier();

    switch (groupBy) {
      case 'Hour':
        // 24 hours - showing key hours
        return [
          FlSpot(0, 50000 * baseMultiplier),    // 6 AM
          FlSpot(1, 120000 * baseMultiplier),   // 8 AM
          FlSpot(2, 280000 * baseMultiplier),   // 10 AM
          FlSpot(3, 450000 * baseMultiplier),   // 12 PM
          FlSpot(4, 380000 * baseMultiplier),   // 2 PM
          FlSpot(5, 520000 * baseMultiplier),   // 4 PM
          FlSpot(6, 680000 * baseMultiplier),   // 6 PM
          FlSpot(7, 750000 * baseMultiplier),   // 8 PM
          FlSpot(8, 920000 * baseMultiplier),   // 10 PM
        ];
      case 'Day':
        // 30 days - showing key days
        return [
          FlSpot(0, 1200000 * baseMultiplier),  // Day 1
          FlSpot(1, 1500000 * baseMultiplier),  // Day 4
          FlSpot(2, 1800000 * baseMultiplier),  // Day 7
          FlSpot(3, 2100000 * baseMultiplier),  // Day 10
          FlSpot(4, 1950000 * baseMultiplier),  // Day 13
          FlSpot(5, 2400000 * baseMultiplier),  // Day 16
          FlSpot(6, 2200000 * baseMultiplier),  // Day 19
          FlSpot(7, 2600000 * baseMultiplier),  // Day 22
          FlSpot(8, 2300000 * baseMultiplier),  // Day 25
          FlSpot(9, 2800000 * baseMultiplier),  // Day 28
        ];
      case 'Week day':
        // Weekly pattern
        return [
          FlSpot(0, 1800000 * baseMultiplier),  // Monday
          FlSpot(1, 2100000 * baseMultiplier),  // Tuesday
          FlSpot(2, 1650000 * baseMultiplier),  // Wednesday
          FlSpot(3, 2400000 * baseMultiplier),  // Thursday
          FlSpot(4, 2800000 * baseMultiplier),  // Friday
          FlSpot(5, 2200000 * baseMultiplier),  // Saturday
          FlSpot(6, 2450000 * baseMultiplier),  // Sunday
        ];
      default:
        return const [FlSpot(0, 0)];
    }
  }

  double _getTimeFrameMultiplier() {
    switch (timeFrame) {
      case 'Today':
        return 0.4;  // Smaller scale for today
      case 'This Week':
        return 1.0;  // Base scale
      case 'This Month':
        return 3.2;  // Larger scale for month
      case 'Last 30 Days':
        return 2.8;  // Similar to month
      default:
        return 1.0;
    }
  }

  double _getMaxX() {
    switch (groupBy) {
      case 'Hour':
        return 8; // 9 data points (0-8)
      case 'Day':
        return 9; // 10 data points (0-9)
      case 'Week day':
        return 6; // 7 days (0-6)
      default:
        return 6;
    }
  }

  double _getMaxY() {
    final data = _getChartData();
    final maxValue = data.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);

    // Smart scaling - round up to nice numbers
    if (maxValue <= 1000000) {
      return ((maxValue / 200000).ceil() * 200000).toDouble(); // Round to nearest 200K
    } else if (maxValue <= 5000000) {
      return ((maxValue / 500000).ceil() * 500000).toDouble(); // Round to nearest 500K
    } else if (maxValue <= 10000000) {
      return ((maxValue / 1000000).ceil() * 1000000).toDouble(); // Round to nearest 1M
    } else {
      return ((maxValue / 2000000).ceil() * 2000000).toDouble(); // Round to nearest 2M
    }
  }

  double _getYAxisInterval() {
    final maxY = _getMaxY();

    if (maxY <= 1000000) {
      return 200000; // 200K intervals
    } else if (maxY <= 5000000) {
      return 500000; // 500K intervals
    } else if (maxY <= 10000000) {
      return 1000000; // 1M intervals
    } else {
      return 2000000; // 2M intervals
    }
  }

  String _getBottomTitle(int value) {
    switch (groupBy) {
      case 'Hour':
        // Hour labels
        switch (value) {
          case 0: return '6AM';
          case 1: return '8AM';
          case 2: return '10AM';
          case 3: return '12PM';
          case 4: return '2PM';
          case 5: return '4PM';
          case 6: return '6PM';
          case 7: return '8PM';
          case 8: return '10PM';
          default: return '';
        }
      case 'Day':
        // Day labels
        switch (value) {
          case 0: return '1';
          case 1: return '4';
          case 2: return '7';
          case 3: return '10';
          case 4: return '13';
          case 5: return '16';
          case 6: return '19';
          case 7: return '22';
          case 8: return '25';
          case 9: return '28';
          default: return '';
        }
      case 'Week day':
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
      default:
        return '';
    }
  }
}