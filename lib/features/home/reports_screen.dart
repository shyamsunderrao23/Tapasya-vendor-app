import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'package:tapasya_vendor_app/core/utils/transaction_stats_utils.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:tapasya_vendor_app/features/home/vendor_provider.dart';
import 'package:tapasya_vendor_app/core/widgets/app_toast.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _appliedDate = DateTime.now();
  int _viewMonth = DateTime.now().month;
  int _viewYear = DateTime.now().year;
  
  List<DateTime> _availableMonths = []; // Used for history range detection
  bool _isLoading = false;
  bool _showAllHistory = false;
  int _historyLimit = 10;

  @override
  void initState() {
    super.initState();
    _viewMonth = _appliedDate.month;
    _viewYear = _appliedDate.year;
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vProv = context.read<VendorProvider>();
      if (vProv.transactionsData.isEmpty) {
        await vProv.fetchTransactions();
      }
      if (vProv.profileFullData == null) {
        await vProv.fetchProfileFull();
      }
      _initializeMonths();
      _fetchMonthData();
    });
  }

  void _initializeMonths() {
    final vendorProv = context.read<VendorProvider>();
    final profile = vendorProv.profileFullData;
    final transactions = vendorProv.transactionsData;
    
    DateTime joinDate = DateTime.now(); 
    if (profile != null) {
      final cAt = profile['created_at'] ?? (profile['vendor'] != null ? profile['vendor']['created_at'] : null);
      if (cAt != null) {
        try {
          joinDate = DateTime.parse(cAt.toString());
        } catch (_) {}
      }
    }

    for (var tx in transactions) {
      try {
        final txDate = DateTime.parse(tx['created_at'] ?? tx['booking_date'] ?? '');
        if (txDate.isBefore(joinDate)) {
          joinDate = txDate;
        }
      } catch (_) {}
    }

    final List<DateTime> months = [];
    DateTime runner = DateTime(joinDate.year, joinDate.month);
    DateTime today = DateTime.now();
    DateTime limit = DateTime(today.year, today.month);

    while (!runner.isAfter(limit)) {
      months.add(runner);
      runner = DateTime(runner.year, runner.month + 1);
    }

    setState(() {
      _availableMonths = months.reversed.toList();
    });
  }

  Future<void> _fetchMonthData() async {
    setState(() {
      _isLoading = true;
      _appliedDate = DateTime(_viewYear, _viewMonth);
      _showAllHistory = false;
    });
    try {
      final vendorProv = context.read<VendorProvider>();
      await vendorProv.fetchTransactions();
      await vendorProv.fetchAllJobs();
    } catch (e) {
      debugPrint("Report Fetch Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _getMonthlyStats(List<dynamic> transactions, DateTime month) {
    return TransactionStatsUtils.monthlyStats(transactions, month);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VendorProvider>(
      builder: (context, vendorProv, _) {
        final earningRecords = TransactionStatsUtils.mergeEarningRecords(
          transactions: vendorProv.transactionsData,
          completedBookings: vendorProv.jobsByStatus['completed'] ?? [],
        );
        final reportData = TransactionStatsUtils.monthlyStats(earningRecords, _appliedDate);
        
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          body: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : SingleChildScrollView(
                child: Column(
                  children: [
                    _buildUpgradedHeader(reportData),
                    const SizedBox(height: 12),
                    _buildMiniStatCards(reportData),
                    const SizedBox(height: 32),
                    _buildChartSection(reportData),
                    const SizedBox(height: 32),
                    _buildHistorySection(vendorProv.transactionsData),
                    const SizedBox(height: 120), 
                  ],
                ),
              ),
          bottomSheet: _buildDownloadActions(),
        );
      }
    );
  }

  Widget _buildUpgradedHeader(Map<String, dynamic> data) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(60), bottomRight: Radius.circular(60)),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _BubbleBackgroundPainter())),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          const SizedBox(width: 20),
                          const Text(
                            "Monthly Reports", 
                            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  
                  // 2. TWO-TIER FILTER ROW (MONTH & YEAR)
                  Row(
                    children: [
                      // Month Selector
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showMonthPicker(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                                  child: const Icon(Icons.calendar_month_rounded, color: AppTheme.primaryColor, size: 16),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Month", style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                                      Text(DateFormat('MMMM').format(DateTime(2024, _viewMonth)), style: const TextStyle(color: Color(0xFF1B263B), fontSize: 14, fontWeight: FontWeight.w900)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Year Selector
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showYearPicker(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
                                  child: const Icon(Icons.event_rounded, color: Colors.orange, size: 16),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Year", style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                                      Text(_viewYear.toString(), style: const TextStyle(color: Color(0xFF1B263B), fontSize: 14, fontWeight: FontWeight.w900)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
                  
                  const SizedBox(height: 20),
                  
                  // 3. APPLY FILTER BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _fetchMonthData(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.filter_list_rounded, size: 18),
                          SizedBox(width: 8),
                          Text("Filter Result", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
                  
                  const SizedBox(height: 12),
                  const Text(
                    "Select month and year then click Filter Result",
                    style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1, end: 0, curve: Curves.easeOutCubic);
  }

  void _showMonthPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 32),
            const Text("Select Month", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1B263B))),
            const SizedBox(height: 32),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: 12, // Always show all 12 months
                itemBuilder: (context, index) {
                  final mIndex = index + 1;
                  final isSelected = _viewMonth == mIndex;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      onTap: () {
                        setState(() => _viewMonth = mIndex);
                        Navigator.pop(context);
                      },
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      tileColor: isSelected ? AppTheme.primaryColor.withOpacity(0.08) : Colors.grey.shade50,
                      leading: Icon(
                        Icons.calendar_month_rounded, 
                        color: isSelected ? AppTheme.primaryColor : Colors.grey.shade400,
                        size: 20,
                      ),
                      title: Text(
                        DateFormat('MMMM').format(DateTime(2024, mIndex)),
                        style: TextStyle(
                          color: isSelected ? AppTheme.primaryColor : const Color(0xFF1B263B),
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                        ),
                      ),
                      trailing: isSelected 
                        ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor)
                        : Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade300, size: 14),
                    ),
                  ).animate().fadeIn(delay: (index * 30).ms).slideX(begin: 0.1, end: 0);
                },
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showYearPicker() {
    // Generate years from available range
    final List<int> years = _availableMonths.map((m) => m.year).toSet().toList();
    if (!years.contains(DateTime.now().year)) years.add(DateTime.now().year);
    years.sort((a, b) => b.compareTo(a));
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 32),
            const Text("Select Year", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1B263B))),
            const SizedBox(height: 32),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: years.length,
                itemBuilder: (context, index) {
                  final year = years[index];
                  final isSelected = _viewYear == year;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                    onTap: () {
                        setState(() => _viewYear = year);
                        Navigator.pop(context);
                      },
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      tileColor: isSelected ? AppTheme.primaryColor.withOpacity(0.08) : Colors.grey.shade50,
                      leading: Icon(
                        Icons.event_rounded, 
                        color: isSelected ? AppTheme.primaryColor : Colors.grey.shade400,
                        size: 20,
                      ),
                      title: Text(
                        year.toString(),
                        style: TextStyle(
                          color: isSelected ? AppTheme.primaryColor : const Color(0xFF1B263B),
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                        ),
                      ),
                      trailing: isSelected 
                        ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor)
                        : Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade300, size: 14),
                    ),
                  ).animate().fadeIn(delay: (index * 30).ms).slideX(begin: 0.1, end: 0);
                },
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStatCards(Map<String, dynamic> data) {
    final double total = data['totalEarnings'];
    final String totalDisplay = total >= 1000 
        ? "₹ ${(total / 1000).toStringAsFixed(1)}k" 
        : "₹ ${total.toInt()}";

    return Transform.translate(
      offset: const Offset(0, -30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            _buildStatCard(totalDisplay, "Total", const Color(0xFF50E3C2)),
            const SizedBox(width: 12),
            _buildStatCard("${data['totalJobs']}", "Missions", const Color(0xFF4A90E2)),
            const SizedBox(width: 12),
            _buildStatCard("${data['completionRate']}%", "Completion", const Color(0xFFF5A623)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String val, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10)),
            BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5)),
          ],
          border: Border.all(color: Colors.grey.shade50),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(_getIconForLabel(label), color: color, size: 16),
            ),
            const SizedBox(height: 12),
            Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1B263B), letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic);
  }

  IconData _getIconForLabel(String label) {
    if (label.contains("Total")) return Icons.payments_rounded;
    if (label.contains("Jobs")) return Icons.business_center_rounded;
    return Icons.analytics_rounded;
  }

  Widget _buildChartSection(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Earnings Trend", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1B263B))),
                Icon(Icons.auto_graph_rounded, color: AppTheme.primaryColor.withOpacity(0.3), size: 20),
              ],
            ),
            const SizedBox(height: 30),
            _buildLineChart(data),
            const SizedBox(height: 32),
            const Text("Booking Distribution", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1B263B))),
            const SizedBox(height: 20),
            _buildBarChart(data),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildLineChart(Map<String, dynamic> data) {
    final List<double> earnings = data['earnings'];
    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppTheme.primaryColor.withOpacity(0.8),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) => LineTooltipItem(
                  "₹${spot.y.toInt()}",
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                )).toList();
              },
            ),
          ),
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final int day = value.toInt() + 1;
                  // Show labels for: 1, 10, 20, 30
                  if (day % 10 != 0 && day != 1) return const SizedBox();
                  
                  return Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(day.toString(), style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.bold)),
                  );
                },
                interval: 1,
                reservedSize: 28,
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(earnings.length, (i) => FlSpot(i.toDouble(), earnings[i])),
              isCurved: true,
              curveSmoothness: 0.1,
              color: AppTheme.primaryColor,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: earnings[index] > 0 ? 3 : 0,
                  color: AppTheme.primaryColor,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true, 
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor.withOpacity(0.15), AppTheme.primaryColor.withOpacity(0.0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(Map<String, dynamic> data) {
    final List<int> jobs = data['jobs'];
    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF1B263B).withOpacity(0.9),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  "${rod.toY.toInt()} Jobs",
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                );
              },
            ),
          ),
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final int day = value.toInt() + 1;
                  // Show labels for: 1, 10, 20, 30
                  if (day % 10 != 0 && day != 1) return const SizedBox();
                  
                  return Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(day.toString(), style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.bold)),
                  );
                },
                interval: 1,
                reservedSize: 28,
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(jobs.length, (i) {
            final hasWork = jobs[i] > 0;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: hasWork ? jobs[i].toDouble() : 0.5, // Subtle placeholder for empty days
                  color: hasWork ? AppTheme.primaryColor : Colors.grey.shade200,
                  width: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildHistorySection(List<dynamic>? transactions) {
    // 🔥 FILTER HISTORY BY SELECTED MONTH
    final List<dynamic> allFiltered = TransactionStatsUtils.filterHistory(
      TransactionStatsUtils.mergeEarningRecords(
        transactions: transactions ?? [],
        completedBookings: context.read<VendorProvider>().jobsByStatus['completed'] ?? [],
      ).where((tx) {
        final date = TransactionStatsUtils.parseDate(tx);
        if (date == null) return false;
        return date.year == _appliedDate.year && date.month == _appliedDate.month;
      }).toList(),
    );

    final List<dynamic> filtered = _showAllHistory ? allFiltered : allFiltered.take(_historyLimit).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Monthly Transactions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1B263B))),
              if (allFiltered.length > _historyLimit && !_showAllHistory)
                TextButton(
                  onPressed: () => setState(() => _showAllHistory = true),
                  child: const Text("View All", style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (filtered.isEmpty)
             const Center(child: Padding(
               padding: EdgeInsets.all(40.0),
               child: Text("No transactions for this month.", style: TextStyle(color: Colors.grey)),
             ))
          else
            ...filtered.map((tx) {
              // 🔥 Fallback from service_name to sub_service_name or type
              final String service = (tx['service_name'] ?? tx['sub_service_name'] ?? tx['type'] ?? 'Mission Complete').toString();
              final DateTime dt = DateTime.parse(tx['created_at'] ?? tx['booking_date'] ?? '');
              final String dateStr = DateFormat('dd MMM yyyy').format(dt);
              final String timeStr = DateFormat('hh:mm a').format(dt);
              // 🔥 Supporting final_amount key
              final String amount = "₹ ${tx['final_amount'] ?? tx['amount'] ?? tx['total_amount'] ?? '0'}";
              final Color color = (tx['type']?.toString().toLowerCase() == 'payout') ? Colors.red : Colors.green;
              return _buildHistoryRow(service, "$dateStr • $timeStr", amount, color);
            }),
          
          if (_showAllHistory)
            Center(
              child: TextButton(
                onPressed: () => setState(() => _showAllHistory = false),
                child: const Text("Show Less", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDownloadActions() {
    return Consumer<VendorProvider>(
      builder: (context, vendorProv, _) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, -10))],
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildActionBtn(
                "Monthly PDF", 
                Icons.picture_as_pdf_outlined, 
                () async {
                  final stats = _getMonthlyStats(vendorProv.transactionsData, _appliedDate);
                  final List<dynamic> filtered = (vendorProv.transactionsData ?? []).where((tx) {
                    try {
                      final txDate = DateTime.parse(tx['created_at'] ?? tx['booking_date'] ?? '');
                      return txDate.year == _appliedDate.year && txDate.month == _appliedDate.month;
                    } catch (_) { return false; }
                  }).toList();
                  
                  await _generateAndDownloadPdf(
                    "Monthly Report (${DateFormat('MMM yyyy').format(_appliedDate)})",
                    stats,
                    filtered
                  );
                }
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionBtn(
                "Yearly Summary", 
                Icons.summarize_outlined, 
                () async {
                  final year = _appliedDate.year;
                  final List<dynamic> yearTxs = (vendorProv.transactionsData ?? []).where((tx) {
                    try {
                      final txDate = DateTime.parse(tx['created_at'] ?? tx['booking_date'] ?? '');
                      return txDate.year == year;
                    } catch (_) { return false; }
                  }).toList();

                  double totalEarnings = 0;
                  int totalJobs = 0;
                  int completed = 0;
                  for (var tx in yearTxs) {
                    if (tx is! Map) continue;
                    final txMap = Map<String, dynamic>.from(tx);
                    if (TransactionStatsUtils.isPayout(txMap)) continue;
                    totalJobs++;
                    if (TransactionStatsUtils.countsForEarnings(txMap)) {
                      completed++;
                      totalEarnings += TransactionStatsUtils.parseAmount(txMap);
                    }
                  }

                  await _generateAndDownloadPdf(
                    "Yearly Summary ($year)",
                    {
                      'totalEarnings': totalEarnings,
                      'totalJobs': totalJobs,
                      'completionRate': totalJobs > 0 ? (completed / totalJobs * 100).round() : 0
                    },
                    yearTxs,
                    isYearly: true
                  );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn(String label, IconData icon, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 0,
      ),
    );
  }

  Future<void> _generateAndDownloadPdf(String name, Map<String, dynamic> stats, List<dynamic> transactions, {bool isYearly = false}) async {
    final pdf = pw.Document();
    
    // Load a font that supports Rupee symbol (₹)
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();
    
    // For Yearly: Group by months
    final Map<int, List<dynamic>> monthlyGroups = {};
    if (isYearly) {
      for (var tx in transactions) {
        try {
          final dt = DateTime.parse(tx['created_at'] ?? tx['booking_date'] ?? '');
          monthlyGroups.putIfAbsent(dt.month, () => []).add(tx);
        } catch (_) {}
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Tapasya Vendor Report", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple)),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                    pw.Text(isYearly ? "Annual Summary" : "Monthly Statement", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                  ]
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text("Document Name: $name", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Divider(thickness: 2),
          pw.SizedBox(height: 30),
          
          pw.Text(isYearly ? "ANNUAL PERFORMANCE OVERVIEW" : "FINANCIAL SUMMARY", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple, fontSize: 14)),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(10)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("TOTAL EARNINGS", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                    pw.Text("₹ ${stats['totalEarnings']}", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("TOTAL MISSIONS", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                    pw.Text("${stats['totalJobs']}", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("COMPLETION RATE", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                    pw.Text("${stats['completionRate']}%", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 40),
          pw.Text(isYearly ? "MONTHLY BREAKDOWN" : "TRANSACTION HISTORY", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple, fontSize: 14)),
          pw.SizedBox(height: 10),
          
          if (isYearly)
            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.deepPurple),
              cellHeight: 35,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
              },
              headers: ['Month', 'Earnings', 'Missions', 'Completion %'],
              data: List.generate(12, (index) {
                final monthNum = index + 1;
                final monthData = monthlyGroups[monthNum] ?? [];
                
                double mEarnings = 0;
                int mJobs = 0;
                int mCompleted = 0;
                
                for(var tx in monthData) {
                  final amt = double.tryParse((tx['final_amount'] ?? tx['amount'] ?? '0').toString()) ?? 0.0;
                  final type = tx['type']?.toString().toLowerCase();
                  final status = tx['status']?.toString().toLowerCase();
                  if(type != 'payout') {
                    mJobs++;
                    if(status != 'cancelled' && status != 'failed') {
                      mCompleted++;
                      mEarnings += amt;
                    }
                  }
                }
                
                if (mJobs == 0 && monthNum > DateTime.now().month && DateTime.now().year == _appliedDate.year) return null;
                if (mJobs == 0 && monthNum < 1 && DateTime.now().year == _appliedDate.year) return null;

                return [
                  DateFormat('MMMM').format(DateTime(2026, monthNum)),
                  "₹ $mEarnings",
                  mJobs.toString(),
                  "${mJobs > 0 ? (mCompleted / mJobs * 100).round() : 0}%"
                ];
              }).whereType<List<String>>().toList()
            )
          else
            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.deepPurple),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.center,
              },
              headers: ['Service Detail', 'Date & Time', 'Amount', 'Status'],
              data: transactions.map((tx) {
                final dt = DateTime.parse(tx['created_at'] ?? tx['booking_date'] ?? '');
                return [
                  (tx['service_name'] ?? tx['sub_service_name'] ?? 'Mission').toString(),
                  DateFormat('dd MMM yyyy HH:mm').format(dt),
                  "₹ ${tx['final_amount'] ?? tx['amount'] ?? '0'}",
                  tx['payment_status']?.toString().toUpperCase() ?? 'PAID'
                ];
              }).toList()
            ),
          
          pw.SizedBox(height: 40),
          pw.Footer(
            leading: pw.Text("Download Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            trailing: pw.Text("Generated by Tapasya Vendor App", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
          ),
        ],
      ),
    );

    // Bypassing share sheet - saving direct locally and opening immediately
    try {
      if (Platform.isAndroid) {
        await Permission.storage.request();
      }

      final bytes = await pdf.save();
      final String safeName = name.replaceAll(RegExp(r'[^\w\s\-]'), '_');
      
      // Attempt to save to global Downloads for Android users
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        // Verify path is actually writeable, otherwise fallback to app docs
        if (!await downloadsDir.exists()) {
          downloadsDir = await getApplicationDocumentsDirectory();
        }
      } else {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      final path = "${downloadsDir.path}/$safeName.pdf";
      final file = File(path);
      await file.writeAsBytes(bytes);

      // Instantly open the file as requested
      final result = await OpenFilex.open(path);

      if (mounted) {
        AppToast.show(context, "$name Downloaded & Opened Successfully!");
      }
    } catch (e) {
      // Final reliable fallback if direct write is blocked by OS security
      await Printing.sharePdf(
        bytes: await pdf.save(), 
        filename: "${name.replaceAll(RegExp(r'[^\w\s\-]'), '_')}.pdf"
      );
    }
  }

  void _mockDownload(String name) {
    AppToast.show(context, "Generating $name... ✨ Success! View in downloads.");
  }

  Widget _buildHistoryRow(String title, String date, String amount, Color color) {
    final isExpense = amount.startsWith('-');
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
        border: Border.all(color: Colors.grey.shade50),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isExpense ? Icons.north_east_rounded : Icons.south_west_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1B263B))),
                  const SizedBox(height: 5),
                  Text(date, style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color),
              ),
              const SizedBox(height: 4),
              Text(
                isExpense ? "Debited" : "Credited",
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color.withOpacity(0.5), letterSpacing: 0.5),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
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
