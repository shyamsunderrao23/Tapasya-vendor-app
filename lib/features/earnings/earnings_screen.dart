import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:tapasya_vendor_app/core/utils/transaction_stats_utils.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:tapasya_vendor_app/features/home/vendor_provider.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  String _selectedPeriod = 'Daily';
  final List<String> _periods = ['Daily', 'Weekly', 'Monthly', 'Yearly'];
  int? _selectedChartIndex;
  final ScrollController _lineChartScrollController = ScrollController();
  final ScrollController _barChartScrollController = ScrollController();
  late final ValueNotifier<int> _chartHighlightNotifier;

  @override
  void initState() {
    super.initState();
    _chartHighlightNotifier = ValueNotifier(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  void _fetchData() {
    final provider = context.read<VendorProvider>();
    provider.fetchEarnings();
    provider.fetchTransactions();
    provider.fetchAllJobs();
    provider.fetchProfileFull();
  }

  @override
  void dispose() {
    _chartHighlightNotifier.dispose();
    _lineChartScrollController.dispose();
    _barChartScrollController.dispose();
    super.dispose();
  }

  void _syncHighlightNotifier(int index) {
    if (_chartHighlightNotifier.value != index) {
      _chartHighlightNotifier.value = index;
    }
  }

  void _onChartDaySelected(int idx) {
    if (_selectedChartIndex == idx && _chartHighlightNotifier.value == idx) return;
    _selectedChartIndex = idx;
    _syncHighlightNotifier(idx);
  }

  int _activeChartIndex(
    String period,
    List<String> labels,
  ) {
    if (labels.isEmpty) return 0;
    if (_selectedChartIndex != null && _selectedChartIndex! < labels.length) {
      return _selectedChartIndex!;
    }
    return TransactionStatsUtils.presentPeriodChartIndex(period, labels);
  }

  void _scrollChartsToPresentDate(int index, int pointCount) {
    if (pointCount <= 7 || index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      const pointWidth = 28.0;
      final viewport = MediaQuery.of(context).size.width - 80;
      final offset = (index * pointWidth) - (viewport / 2) + 40;
      final maxScroll = (pointCount * pointWidth) - viewport;
      final clamped = offset.clamp(0.0, maxScroll > 0 ? maxScroll : 0.0);
      for (final controller in [_lineChartScrollController, _barChartScrollController]) {
        if (controller.hasClients) {
          controller.animateTo(
            clamped,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  bool _recordMatchesChartIndex(
    DateTime? date,
    String period,
    List<String> labels,
    int index,
  ) {
    if (date == null || index < 0 || index >= labels.length) return false;
    final now = DateTime.now();

    switch (period) {
      case 'Daily':
        return date.year == now.year &&
            date.month == now.month &&
            date.day == index + 1;
      case 'Weekly':
        final weekStart = TransactionStatsUtils.startOfWeekLocal(now);
        final target = weekStart.add(Duration(days: index));
        return date.year == target.year &&
            date.month == target.month &&
            date.day == target.day;
      case 'Monthly':
        return date.year == now.year && date.month == index + 1;
      case 'Yearly':
        final year = int.tryParse(labels[index].replaceAll('*', ''));
        return year != null && date.year == year;
      default:
        return true;
    }
  }

  Map<String, num> _summaryForIndex(
    int index,
    List<double> earningsValues,
    List<double> jobsValues,
    Map<String, dynamic> viewData,
  ) {
    if (index >= 0 && index < earningsValues.length) {
      return {
        'totalEarnings': earningsValues[index],
        'totalJobs': jobsValues[index].toInt(),
      };
    }
    return {
      'totalEarnings': viewData['totalEarnings'] as double,
      'totalJobs': viewData['totalJobs'] as int,
    };
  }

  String _workCountLabel(String period) {
    switch (period) {
      case 'Daily':
      case 'Weekly':
        return 'Day Work';
      case 'Monthly':
        return 'Month Work';
      case 'Yearly':
        return 'Year Work';
      default:
        return 'Work';
    }
  }

  List<Map<String, dynamic>> _filterRecordsForChartDay({
    required List<dynamic> earningRecords,
    required List<Map<String, dynamic>> bookingRecords,
    required String period,
    required List<String> labels,
    required int index,
  }) {
    final seenIds = <String>{};
    final result = <Map<String, dynamic>>[];

    for (final raw in earningRecords) {
      if (raw is! Map) continue;
      final record = Map<String, dynamic>.from(raw);
      final date = TransactionStatsUtils.parseLocalDate(record);
      if (!_recordMatchesChartIndex(date, period, labels, index)) continue;
      final id = TransactionStatsUtils.recordId(record);
      if (id != null) seenIds.add(id);
      result.add(record);
    }

    for (final record in bookingRecords) {
      final date = TransactionStatsUtils.parseBookingChartDate(record);
      if (!_recordMatchesChartIndex(date, period, labels, index)) continue;
      final id = TransactionStatsUtils.recordId(record);
      if (id != null && seenIds.contains(id)) continue;
      result.add(record);
    }

    return result;
  }

  String _historySectionTitle(String period, List<String> labels, int index, int workCount) {
    if (labels.isEmpty || index < 0 || index >= labels.length) {
      return '$period Transactions';
    }
    final label = labels[index];
    switch (period) {
      case 'Daily':
      case 'Weekly':
        return label == 'Today' ? 'Today · $workCount Work' : 'Day $label · $workCount Work';
      case 'Monthly':
        return 'Month $label · $workCount Work';
      case 'Yearly':
        return 'Year $label · $workCount Work';
      default:
        return '$period Transactions';
    }
  }

  String _summaryCardLabel(String period) {
    switch (period) {
      case 'Daily':
      case 'Weekly':
        return 'Day Total';
      case 'Monthly':
        return 'Month Total';
      case 'Yearly':
        return 'Year Total';
      default:
        return '$period Total';
    }
  }

  String _periodChartSubtitle(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'Daily':
        return DateFormat('MMMM yyyy').format(now);
      case 'Weekly':
        return '${DateFormat('d MMM').format(TransactionStatsUtils.startOfWeekLocal(now))} – ${DateFormat('d MMM yyyy').format(now)}';
      case 'Monthly':
        return now.year.toString();
      case 'Yearly':
        return 'By year';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VendorProvider>(
      builder: (context, provider, child) {
        final mergedRecords = TransactionStatsUtils.mergeEarningRecords(
          transactions: provider.transactionsData,
          completedBookings: provider.jobsByStatus['completed'] ?? [],
        );
        final bookingRecords = TransactionStatsUtils.mergeBookingChartRecords(
          activeBookings: provider.jobsByStatus['active'] ?? [],
          completedBookings: provider.jobsByStatus['completed'] ?? [],
          newBookings: provider.jobsByStatus['new'] ?? [],
        );

        final viewData = TransactionStatsUtils.buildEarningsViewData(
          mergedRecords,
          _selectedPeriod,
          bookingRecords: bookingRecords,
        );

        final labels = List<String>.from(viewData['labels'] as List);
        final earningsValues = List<double>.from(viewData['earningsValues'] as List);
        final jobsValues = List<double>.from(viewData['jobsValues'] as List);
        final activeIndex = _activeChartIndex(
          _selectedPeriod,
          labels,
        );
        if (_selectedChartIndex == null && _chartHighlightNotifier.value != activeIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedChartIndex == null) {
              _chartHighlightNotifier.value = activeIndex;
              _scrollChartsToPresentDate(activeIndex, labels.length);
            }
          });
        }

        final summaryData = {
          'overallTotal': viewData['overallTotal'] as double,
          'overallJobs': viewData['overallJobs'] as int,
        };

        final isLoading = provider.isLoading && mergedRecords.isEmpty;

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async => _fetchData(),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildUpgradedHeader(summaryData),
                        const SizedBox(height: 12),
                        ValueListenableBuilder<int>(
                          valueListenable: _chartHighlightNotifier,
                          builder: (context, highlightIndex, _) {
                            final cardSummary = _summaryForIndex(
                              highlightIndex,
                              earningsValues,
                              jobsValues,
                              viewData,
                            );
                            return _buildMiniStatCards(
                              cardSummary,
                              _selectedPeriod,
                              labels,
                              highlightIndex,
                            );
                          },
                        ),
                        const SizedBox(height: 32),
                        _buildChartSection(
                          labels,
                          earningsValues,
                          jobsValues,
                          _selectedPeriod,
                          _periodChartSubtitle(_selectedPeriod),
                        ),
                        const SizedBox(height: 32),
                        ValueListenableBuilder<int>(
                          valueListenable: _chartHighlightNotifier,
                          builder: (context, highlightIndex, _) {
                            final cardSummary = _summaryForIndex(
                              highlightIndex,
                              earningsValues,
                              jobsValues,
                              viewData,
                            );
                            final filteredTx = _filterRecordsForChartDay(
                              earningRecords: TransactionStatsUtils.filterHistory(mergedRecords),
                              bookingRecords: bookingRecords,
                              period: _selectedPeriod,
                              labels: labels,
                              index: highlightIndex,
                            );
                            return _buildHistorySection(
                              filteredTx,
                              _selectedPeriod,
                              labels,
                              highlightIndex,
                              cardSummary['totalJobs'] as int,
                            );
                          },
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildChartSection(
    List<String> labels,
    List<double> earnings,
    List<double> jobs,
    String period,
    String timeIndicator,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text("Earnings Trend", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1B263B))),
                    const SizedBox(width: 8),
                    Text(timeIndicator, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                  ],
                ),
                Icon(Icons.auto_graph_rounded, color: AppTheme.primaryColor.withOpacity(0.3), size: 20),
              ],
            ),
            const SizedBox(height: 30),
            _buildLineChart(labels, earnings, jobs, period),
            const SizedBox(height: 32),
            Row(
              children: [
                const Text("Booking Distribution", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1B263B))),
                const SizedBox(width: 8),
                Text(timeIndicator, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
              ],
            ),
            const SizedBox(height: 20),
            _buildBarChart(labels, jobs, period),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStatChip({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradedHeader(Map<String, dynamic> data) {
    final overallTotal = (data['overallTotal'] as double).toInt();
    final overallJobs = data['overallJobs'] as int;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 40),
      decoration: const BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(60), bottomRight: Radius.circular(60)),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _BubbleBackgroundPainter())),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Earnings",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Your overall performance",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildHeaderStatChip(
                          icon: Icons.account_balance_wallet_outlined,
                          value: '₹ $overallTotal',
                          label: 'Total earnings',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildHeaderStatChip(
                          icon: Icons.check_circle_outline_rounded,
                          value: '$overallJobs',
                          label: 'Total work',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // PERIOD SELECTOR
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _periods.map((period) {
                        final isSelected = _selectedPeriod == period;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              if (_selectedPeriod == period) return;
                              setState(() {
                                _selectedPeriod = period;
                                _selectedChartIndex = null;
                                _chartHighlightNotifier.value = 0;
                              });
                            },
                            child: AnimatedContainer(
                              duration: 200.ms,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isSelected ? Colors.transparent : Colors.white24),
                              ),
                              child: Text(
                                period,
                                style: TextStyle(
                                  color: isSelected ? AppTheme.primaryColor : Colors.white,
                                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildMiniStatCards(
    Map<String, num> data,
    String period,
    List<String> labels,
    int highlightIndex,
  ) {
    final totalEarnings = data['totalEarnings']!.toDouble();
    final totalJobs = data['totalJobs']!.toInt();
    final avgPerJob = totalJobs > 0 ? (totalEarnings / totalJobs).round() : 0;
    final periodLabel = _summaryCardLabel(period);
    final workLabel = _workCountLabel(period);
    final selectionHint = labels.isNotEmpty && highlightIndex < labels.length ? ' · ${labels[highlightIndex]}' : '';

    return Transform.translate(
      offset: const Offset(0, -30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            _buildStatCard("₹ ${totalEarnings.toInt()}", "$periodLabel$selectionHint", const Color(0xFF50E3C2)),
            const SizedBox(width: 12),
            _buildStatCard("$totalJobs", "$workLabel$selectionHint", const Color(0xFF4A90E2)),
            const SizedBox(width: 12),
            _buildStatCard("₹ $avgPerJob", "Avg / Job", const Color(0xFFF5A623)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String val, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
          border: Border.all(color: Colors.white),
        ),
        child: Column(
          children: [
            Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1B263B))),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }


  double _chartContentWidth(int pointCount) {
    if (pointCount <= 7) return MediaQuery.of(context).size.width - 80;
    return pointCount * 28.0;
  }

  double _yAxisInterval(double maxVal, {int steps = 4}) {
    if (maxVal <= 0) return 1;
    final raw = maxVal / steps;
    if (raw <= 1) return 1;
    if (raw <= 5) return 5;
    if (raw <= 10) return 10;
    if (raw <= 50) return 50;
    if (raw <= 100) return 100;
    if (raw <= 500) return 500;
    if (raw <= 1000) return 1000;
    return (raw / 1000).ceil() * 1000.0;
  }

  static const double _chartHeight = 240;
  static const double _bottomAxisSize = 32;
  static const double _plotHeight = _chartHeight - _bottomAxisSize;
  static const double _lineLeftAxisWidth = 38;
  static const double _barLeftAxisWidth = 18;

  List<double> _yAxisTicks(double maxY, double interval) {
    final ticks = <double>[];
    for (var v = 0.0; v <= maxY + 0.0001; v += interval) {
      ticks.add(v);
    }
    if (ticks.isEmpty) ticks.add(0);
    return ticks;
  }

  /// Sticky left Y-axis — flush left, aligned with chart section title.
  Widget _buildStickyYAxisLabels({
    required double maxY,
    required double interval,
    required double width,
    required String Function(double value) formatLabel,
    double fontSize = 10,
  }) {
    final ticks = _yAxisTicks(maxY, interval).reversed.toList();

    return SizedBox(
      width: width,
      height: _chartHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: ticks.map((value) {
                  return Text(
                    formatLabel(value),
                    textAlign: TextAlign.left,
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: _bottomAxisSize),
        ],
      ),
    );
  }

  Widget _buildStickyLeftChartRow({
    required double leftAxisWidth,
    required double scrollContentWidth,
    required ScrollController scrollController,
    required Widget fixedLeftAxis,
    required Widget scrollableChart,
  }) {
    return SizedBox(
      height: _chartHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          fixedLeftAxis,
          Container(
            width: 1,
            height: _chartHeight,
            color: Colors.grey.shade200,
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: scrollContentWidth,
                height: _chartHeight,
                child: scrollableChart,
              ),
            ),
          ),
        ],
      ),
    );
  }

  FlGridData _chartGridData({required bool verticalLines}) {
    return FlGridData(
      show: true,
      drawVerticalLine: verticalLines,
      drawHorizontalLine: true,
      getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
      getDrawingVerticalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1, dashArray: [4, 4]),
    );
  }

  AxisTitles _hiddenLeftAxis() {
    return const AxisTitles(
      sideTitles: SideTitles(showTitles: false, reservedSize: 0),
    );
  }

  Widget _buildLineChart(
    List<String> labels,
    List<double> earnings,
    List<double> jobs,
    String period,
  ) {
    if (earnings.isEmpty) {
      return const SizedBox(height: 240, child: Center(child: Text("No data available")));
    }

    double maxE = 0;
    for (final e in earnings) {
      if (e > maxE) maxE = e;
    }
    if (maxE == 0) maxE = 100;
    final interval = _yAxisInterval(maxE);
    final maxY = (maxE * 1.25 / interval).ceil() * interval;
    final chartWidth = _chartContentWidth(earnings.length);

    return RepaintBoundary(
      child: ValueListenableBuilder<int>(
        valueListenable: _chartHighlightNotifier,
        builder: (context, highlightedIndex, _) {
          final fixedAxis = _buildStickyYAxisLabels(
            maxY: maxY,
            interval: interval,
            width: _lineLeftAxisWidth,
            formatLabel: (v) => '₹${v.toInt()}',
            fontSize: 9,
          );

          final scrollChart = LineChart(
            LineChartData(
              minX: 0,
              maxX: (earnings.length - 1).toDouble(),
              minY: 0,
              maxY: maxY,
              clipData: const FlClipData.all(),
              gridData: _chartGridData(verticalLines: true),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: _hiddenLeftAxis(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    reservedSize: _bottomAxisSize,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= labels.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          labels[index],
                          style: TextStyle(
                            color: index == highlightedIndex ? AppTheme.primaryColor : Colors.grey.shade500,
                            fontSize: 9,
                            fontWeight: index == highlightedIndex ? FontWeight.w900 : FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                handleBuiltInTouches: true,
                touchCallback: (event, response) {
                  if (!event.isInterestedForInteractions || response?.lineBarSpots == null) return;
                  final idx = response!.lineBarSpots!.first.x.toInt();
                  if (idx >= 0 && idx < labels.length) {
                    _onChartDaySelected(idx);
                  }
                },
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => const Color(0xFF1B263B),
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final idx = spot.x.toInt();
                      final label = idx < labels.length ? labels[idx] : '';
                      final workCount = idx < jobs.length ? jobs[idx].toInt() : 0;
                      return LineTooltipItem(
                        '$label\n₹${spot.y.toInt()}\n$workCount Work',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, height: 1.4),
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(earnings.length, (i) => FlSpot(i.toDouble(), earnings[i])),
                  isCurved: true,
                  curveSmoothness: 0.22,
                  preventCurveOverShooting: true,
                  color: AppTheme.primaryColor,
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      final active = index == highlightedIndex;
                      final hasValue = index < earnings.length &&
                          index < jobs.length &&
                          (earnings[index] > 0 || jobs[index] > 0);
                      return FlDotCirclePainter(
                        radius: active ? 5 : (hasValue ? 3.5 : 0),
                        color: active ? Colors.white : AppTheme.primaryColor,
                        strokeWidth: active ? 3 : 0,
                        strokeColor: AppTheme.primaryColor,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor.withValues(alpha: 0.22),
                        AppTheme.primaryColor.withValues(alpha: 0.02),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
              extraLinesData: ExtraLinesData(
                verticalLines: highlightedIndex >= 0 && highlightedIndex < earnings.length
                    ? [
                        VerticalLine(
                          x: highlightedIndex.toDouble(),
                          color: AppTheme.primaryColor.withValues(alpha: 0.25),
                          strokeWidth: 1.5,
                          dashArray: [6, 4],
                        ),
                      ]
                    : [],
              ),
            ),
          );

          return _buildStickyLeftChartRow(
            leftAxisWidth: _lineLeftAxisWidth,
            scrollContentWidth: chartWidth,
            scrollController: _lineChartScrollController,
            fixedLeftAxis: fixedAxis,
            scrollableChart: scrollChart,
          );
        },
      ),
    );
  }

  Widget _buildBarChart(List<String> labels, List<double> jobs, String period) {
    if (jobs.isEmpty) {
      return const SizedBox(height: 240, child: Center(child: Text("No data available")));
    }

    double maxJ = 0;
    for (final j in jobs) {
      if (j > maxJ) maxJ = j;
    }
    if (maxJ == 0) maxJ = 5;
    final interval = _yAxisInterval(maxJ, steps: 4).clamp(1, 9999).toDouble();
    final maxY = (maxJ * 1.25 / interval).ceil() * interval;
    final chartWidth = _chartContentWidth(jobs.length);
    final barWidth = jobs.length > 20 ? 6.0 : (jobs.length > 12 ? 10.0 : 18.0);

    return RepaintBoundary(
      child: ValueListenableBuilder<int>(
        valueListenable: _chartHighlightNotifier,
        builder: (context, highlightedIndex, _) {
          final fixedAxis = _buildStickyYAxisLabels(
            maxY: maxY,
            interval: interval,
            width: _barLeftAxisWidth,
            formatLabel: (v) => v.toInt().toString(),
          );

          final scrollChart = BarChart(
            BarChartData(
              minY: 0,
              maxY: maxY,
              gridData: _chartGridData(verticalLines: true),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: _hiddenLeftAxis(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    reservedSize: _bottomAxisSize,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= labels.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          labels[index],
                          style: TextStyle(
                            color: index == highlightedIndex ? AppTheme.primaryColor : Colors.grey.shade500,
                            fontSize: 9,
                            fontWeight: index == highlightedIndex ? FontWeight.w900 : FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                enabled: true,
                touchCallback: (event, response) {
                  if (!event.isInterestedForInteractions || response?.spot == null) return;
                  final idx = response!.spot!.touchedBarGroupIndex;
                  if (idx >= 0 && idx < labels.length) {
                    _onChartDaySelected(idx);
                  }
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => const Color(0xFF1B263B),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final label = groupIndex < labels.length ? labels[groupIndex] : '';
                    final prefix = period == 'Monthly'
                        ? 'Month'
                        : (period == 'Yearly' ? 'Year' : 'Day');
                    return BarTooltipItem(
                      '$prefix $label\n${rod.toY.toInt()} Jobs',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, height: 1.4),
                    );
                  },
                ),
              ),
              barGroups: List.generate(jobs.length, (i) {
                final count = jobs[i];
                final hasWork = count > 0;
                final active = i == highlightedIndex;
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: hasWork ? count : 0.15,
                      width: barWidth,
                      color: active
                          ? AppTheme.primaryColor
                          : (hasWork ? AppTheme.primaryColor.withValues(alpha: 0.35) : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(barWidth),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxY,
                        color: Colors.grey.shade50,
                      ),
                    ),
                  ],
                );
              }),
            ),
          );

          return _buildStickyLeftChartRow(
            leftAxisWidth: _barLeftAxisWidth,
            scrollContentWidth: chartWidth,
            scrollController: _barChartScrollController,
            fixedLeftAxis: fixedAxis,
            scrollableChart: scrollChart,
          );
        },
      ),
    );
  }

  Widget _buildHistorySection(
    List<dynamic> transactions,
    String period,
    List<String> labels,
    int activeIndex,
    int workCount,
  ) {
    final title = _historySectionTitle(period, labels, activeIndex, workCount);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1B263B)),
          ),
          const SizedBox(height: 20),
          if (transactions.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No bookings for this day", style: TextStyle(color: Colors.grey))))
          else
            ...transactions.map((tx) {
              final amount = TransactionStatsUtils.parseAmount(Map<String, dynamic>.from(tx as Map)).toInt();
              final isPaid = tx['type'] == 'Service Payment' || tx['payment_status'] == 'paid';
              final isActiveBooking = tx['type'] == 'booking';
              final createdAt = tx['formatted_date'] ??
                  (TransactionStatsUtils.parseDate(Map<String, dynamic>.from(tx as Map)) != null
                      ? DateFormat('dd MMM, hh:mm a').format(
                          TransactionStatsUtils.parseDate(Map<String, dynamic>.from(tx as Map))!,
                        )
                      : 'Unknown Date');
              final title = tx['service_name']?.toString() ??
                  tx['sub_service_name']?.toString() ??
                  tx['type']?.toString() ??
                  (isPaid ? 'Service Payment' : 'Withdrawal');
              
              return _buildHistoryRow(
                title,
                createdAt,
                "₹ $amount",
                isPaid ? Colors.green : (isActiveBooking ? AppTheme.primaryColor : Colors.red),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(String title, String date, String amount, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(amount.startsWith('-') ? Icons.north_east_rounded : Icons.south_west_rounded, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1B263B))),
                  const SizedBox(height: 4),
                  Text(date, style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          Text(amount, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: color)),
        ],
      ),
    );
  }
}

class _BubbleBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.05)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.2), 40, paint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.1), 60, paint);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.7), 80, paint);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.8), 50, paint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.4), 30, paint);
    final strokePaint = Paint()..color = Colors.white.withOpacity(0.03)..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.5), 90, strokePaint);
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.3), 70, strokePaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
