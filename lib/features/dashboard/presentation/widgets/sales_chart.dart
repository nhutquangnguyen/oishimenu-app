import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SalesChart extends StatelessWidget {
  final String timeFrame;
  final String groupBy;
  final List<Map<String, dynamic>> salesData;

  const SalesChart({
    super.key,
    required this.timeFrame,
    required this.groupBy,
    required this.salesData,
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
    if (salesData.isEmpty) {
      return const [FlSpot(0, 0)];
    }

    switch (groupBy) {
      case 'Hour':
        return _getHourlyChartData();
      case 'Day':
        return _getDailyChartData();
      case 'Week day':
        return _getWeeklyChartData();
      default:
        return _getDailyChartData();
    }
  }

  List<FlSpot> _getHourlyChartData() {
    // Create a map to hold hourly data
    final Map<int, double> hourlyData = {};

    // Initialize with 0 for all hours
    for (int i = 0; i < 24; i++) {
      hourlyData[i] = 0;
    }

    // Process the sales data
    for (final item in salesData) {
      final period = item['period'] as String;
      final sales = (item['sales'] as num?)?.toDouble() ?? 0.0;

      try {
        // Parse hour from period (format: '2024-10-28 14:00')
        final dateTime = DateTime.parse(period.replaceAll(' ', 'T'));
        hourlyData[dateTime.hour] = (hourlyData[dateTime.hour] ?? 0) + sales;
      } catch (e) {
        print('Error parsing hour data: $e');
      }
    }

    // Convert to FlSpot list, sampling key hours for better chart readability
    final List<FlSpot> spots = [];
    final keyHours = [6, 8, 10, 12, 14, 16, 18, 20, 22]; // Key business hours

    for (int i = 0; i < keyHours.length; i++) {
      final hour = keyHours[i];
      spots.add(FlSpot(i.toDouble(), hourlyData[hour] ?? 0));
    }

    return spots;
  }

  List<FlSpot> _getDailyChartData() {
    // Sort data by period and take up to 10 most recent points for chart readability
    final sortedData = List<Map<String, dynamic>>.from(salesData);
    sortedData.sort((a, b) => (a['period'] as String).compareTo(b['period'] as String));

    // Take last 10 days or available data
    final recentData = sortedData.length > 10
        ? sortedData.sublist(sortedData.length - 10)
        : sortedData;

    final List<FlSpot> spots = [];
    for (int i = 0; i < recentData.length; i++) {
      final sales = (recentData[i]['sales'] as num?)?.toDouble() ?? 0.0;
      spots.add(FlSpot(i.toDouble(), sales));
    }

    return spots.isEmpty ? [const FlSpot(0, 0)] : spots;
  }

  List<FlSpot> _getWeeklyChartData() {
    // Create a map to hold weekly data (0 = Monday, 6 = Sunday)
    final Map<int, double> weeklyData = {};

    // Initialize with 0 for all days
    for (int i = 0; i < 7; i++) {
      weeklyData[i] = 0;
    }

    // Process the sales data
    for (final item in salesData) {
      final period = item['period'] as String;
      final sales = (item['sales'] as num?)?.toDouble() ?? 0.0;

      try {
        final dateTime = DateTime.parse(period);
        // Convert to 0-based weekday (0 = Monday, 6 = Sunday)
        final weekday = dateTime.weekday - 1;
        weeklyData[weekday] = (weeklyData[weekday] ?? 0) + sales;
      } catch (e) {
        print('Error parsing weekly data: $e');
      }
    }

    // Convert to FlSpot list
    final List<FlSpot> spots = [];
    for (int i = 0; i < 7; i++) {
      spots.add(FlSpot(i.toDouble(), weeklyData[i] ?? 0));
    }

    return spots;
  }


  double _getMaxX() {
    final data = _getChartData();
    if (data.isEmpty) return 6;

    switch (groupBy) {
      case 'Hour':
        return 8; // 9 key hours (0-8)
      case 'Day':
        return (data.length - 1).toDouble(); // Dynamic based on data points
      case 'Week day':
        return 6; // 7 days (0-6)
      default:
        return (data.length - 1).toDouble();
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
        // Hour labels for key business hours
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
        // Dynamic day labels based on real data
        if (salesData.isEmpty) return '';

        final sortedData = List<Map<String, dynamic>>.from(salesData);
        sortedData.sort((a, b) => (a['period'] as String).compareTo(b['period'] as String));

        final recentData = sortedData.length > 10
            ? sortedData.sublist(sortedData.length - 10)
            : sortedData;

        if (value >= 0 && value < recentData.length) {
          try {
            final period = recentData[value]['period'] as String;
            final date = DateTime.parse(period);
            return '${date.day}/${date.month}';
          } catch (e) {
            return '${value + 1}';
          }
        }
        return '';
      case 'Week day':
        // Weekday labels
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