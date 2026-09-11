/// Shared rules for earnings / reports / dashboard transaction math.
import 'package:intl/intl.dart';

class TransactionStatsUtils {
  static double parseAmount(Map<String, dynamic> tx) {
    final raw = tx['final_amount'] ?? tx['amount'] ?? tx['total_amount'] ?? '0';
    return double.tryParse(raw.toString()) ?? 0.0;
  }

  static String? txStatus(Map<String, dynamic> tx) {
    return tx['status']?.toString().toLowerCase();
  }

  static String? txType(Map<String, dynamic> tx) {
    return tx['type']?.toString().toLowerCase();
  }

  static bool isPayout(Map<String, dynamic> tx) => txType(tx) == 'payout';

  static bool isTerminalFailure(Map<String, dynamic> tx) {
    final status = txStatus(tx);
    return status == 'cancelled' || status == 'failed' || status == 'rejected';
  }

  /// Count toward earnings totals and charts.
  static bool countsForEarnings(Map<String, dynamic> tx) {
    if (isPayout(tx)) return false;
    return !isTerminalFailure(tx);
  }

  /// Hide failed/cancelled/rejected jobs from earnings history (payouts still shown).
  static bool showInEarningsHistory(Map<String, dynamic> tx) {
    if (isPayout(tx)) return true;
    return !isTerminalFailure(tx);
  }

  static DateTime? parseDate(Map<String, dynamic> tx) {
    for (final key in [
      'created_at',
      'completed_at',
      'updated_at',
      'booking_date',
      'date',
    ]) {
      final raw = tx[key];
      if (raw == null || raw.toString().trim().isEmpty) continue;
      try {
        return DateTime.parse(raw.toString());
      } catch (_) {}
    }
    return null;
  }

  /// Calendar date in device local timezone (ignores time-of-day).
  static DateTime localDateOnly(DateTime dt) {
    final local = dt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static DateTime? parseLocalDate(Map<String, dynamic> tx) {
    final parsed = parseDate(tx);
    return parsed != null ? localDateOnly(parsed) : null;
  }

  static DateTime startOfWeekLocal(DateTime date) {
    return localDateOnly(date).subtract(Duration(days: date.weekday - 1));
  }

  static String? recordId(Map<String, dynamic> data) {
    final id = data['booking_id'] ?? data['id'];
    if (id == null || id.toString().trim().isEmpty) return null;
    return id.toString();
  }

  static String bookingStatus(Map<String, dynamic> job) {
    for (final key in ['status', 'booking_status', 'state']) {
      final raw = job[key];
      if (raw != null && raw.toString().trim().isNotEmpty) {
        return raw.toString().toLowerCase().trim();
      }
    }
    return '';
  }

  static bool isCompletedBooking(Map<String, dynamic> job) {
    final status = bookingStatus(job);
    return status == 'completed' ||
        status == 'finished' ||
        status == 'success' ||
        status == 'done' ||
        status == 'closed';
  }

  /// Completed or cancelled — should not appear in In Progress lists.
  static bool isTerminalBooking(Map<String, dynamic> job) {
    return isCancelledBooking(job) || isCompletedBooking(job);
  }

  /// Only jobs the vendor has accepted and is actively working on.
  static bool isInProgressBooking(Map<String, dynamic> job) {
    if (isTerminalBooking(job)) return false;

    const inProgress = {
      'accepted',
      'started',
      'started_job',
      'active',
      'in_progress',
      'in progress',
      'ongoing',
      'confirmed',
    };
    return inProgress.contains(bookingStatus(job));
  }

  /// Bookings API → same shape as a paid transaction for charts.
  static Map<String, dynamic> bookingAsEarningRecord(Map<String, dynamic> job) {
    return {
      'booking_id': job['booking_id'] ?? job['id'],
      'id': job['id'] ?? job['booking_id'],
      'final_amount': job['final_amount'] ?? job['amount'] ?? job['price'] ?? job['total_amount'],
      'amount': job['amount'] ?? job['final_amount'] ?? job['price'],
      'status': 'completed',
      'type': 'Service Payment',
      'payment_status': 'paid',
      'booking_date': job['booking_date'] ?? job['date'],
      'created_at': job['completed_at'] ?? job['updated_at'] ?? job['booking_date'] ?? job['date'],
      'service_name': job['service_name'],
      'sub_service_name': job['sub_service_name'],
      'user_name': job['user_name'],
    };
  }

  /// Merge /transactions with /bookings?status=completed so charts match Jobs tab.
  static List<Map<String, dynamic>> mergeEarningRecords({
    required List<dynamic> transactions,
    required List<dynamic> completedBookings,
  }) {
    final records = <Map<String, dynamic>>[];
    final seenIds = <String>{};

    for (final raw in transactions) {
      if (raw is! Map) continue;
      final tx = Map<String, dynamic>.from(raw);
      if (!countsForEarnings(tx)) continue;
      records.add(tx);
      final id = recordId(tx);
      if (id != null) seenIds.add(id);
    }

    for (final raw in completedBookings) {
      if (raw is! Map) continue;
      final job = Map<String, dynamic>.from(raw);
      if (!isCompletedBooking(job)) continue;
      final id = recordId(job);
      if (id != null && seenIds.contains(id)) continue;
      records.add(bookingAsEarningRecord(job));
      if (id != null) seenIds.add(id);
    }

    return records;
  }

  /// Same totals as Earnings screen — merged /transactions + completed bookings.
  static Map<String, num> lifetimeAndMonthStats({
    required List<dynamic> transactions,
    required List<dynamic> completedBookings,
  }) {
    final records = mergeEarningRecords(
      transactions: transactions,
      completedBookings: completedBookings,
    );
    final now = DateTime.now();
    double totalEarn = 0;
    int totalJobs = 0;
    double monthEarn = 0;
    int monthJobs = 0;

    for (final r in records) {
      final amt = parseAmount(r);
      totalEarn += amt;
      totalJobs++;
      final date = parseLocalDate(r);
      if (date != null && isInSelectedPeriod(date, 'Monthly', now)) {
        monthEarn += amt;
        monthJobs++;
      }
    }

    return {
      'totalEarnings': totalEarn,
      'totalJobs': totalJobs,
      'monthEarnings': monthEarn,
      'monthJobs': monthJobs,
    };
  }

  static bool hasEarningsContent(Map<String, dynamic> data) {
    final summary = data['summary'];
    if (summary is Map) {
      final overall = double.tryParse(summary['overall_total']?.toString() ?? '0') ?? 0;
      if (overall > 0) return true;
      for (final key in ['daily', 'weekly', 'monthly']) {
        final period = summary[key];
        if (period is Map) {
          final total = double.tryParse(period['total']?.toString() ?? '0') ?? 0;
          if (total > 0) return true;
        }
      }
    }
    for (final key in ['day_wise', 'week_wise', 'month_wise']) {
      final list = data[key];
      if (list is! List) continue;
      for (final item in list) {
        if (item is! Map) continue;
        final earnings = double.tryParse(item['earnings']?.toString() ?? '0') ?? 0;
        if (earnings > 0) return true;
      }
    }
    return false;
  }

  /// Fallback when GET /main-earnings is empty — built from /transactions.
  static Map<String, dynamic> buildFallbackEarningsData(List<dynamic> transactions) {
    final now = DateTime.now();
    final dayMap = <String, _Bucket>{};
    final weekMap = <String, _Bucket>{};
    final monthMap = <String, _Bucket>{};
    double overallTotal = 0;

    for (final raw in transactions) {
      if (raw is! Map) continue;
      final tx = Map<String, dynamic>.from(raw);
      if (!countsForEarnings(tx)) continue;

      final date = parseDate(tx);
      if (date == null) continue;

      final amt = parseAmount(tx);
      overallTotal += amt;

      final dayKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      dayMap.putIfAbsent(dayKey, _Bucket.new).add(amt);

      if (date.year == now.year) {
        final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        monthMap.putIfAbsent(monthKey, _Bucket.new).add(amt);

        if (date.month == now.month) {
          final weekNum = ((date.day - 1) ~/ 7) + 1;
          final weekKey = '${now.year}-W${weekNum.toString().padLeft(2, '0')}';
          weekMap.putIfAbsent(weekKey, _Bucket.new).add(amt);
        }
      }
    }

    double monthTotal = 0;
    int monthJobs = 0;
    final currentMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    if (monthMap.containsKey(currentMonthKey)) {
      monthTotal = monthMap[currentMonthKey]!.earnings;
      monthJobs = monthMap[currentMonthKey]!.jobs;
    }

    double weekTotal = 0;
    int weekJobs = 0;
    for (final bucket in weekMap.values) {
      weekTotal += bucket.earnings;
      weekJobs += bucket.jobs;
    }

    return {
      'summary': {
        'overall_total': overallTotal.toStringAsFixed(0),
        'daily': {'total': monthTotal.toStringAsFixed(0), 'jobs': monthJobs.toString()},
        'weekly': {'total': weekTotal.toStringAsFixed(0), 'jobs': weekJobs.toString()},
        'monthly': {'total': monthTotal.toStringAsFixed(0), 'jobs': monthJobs.toString()},
      },
      'day_wise': dayMap.entries
          .map((e) => {'date': e.key, 'earnings': e.value.earnings.toStringAsFixed(0), 'jobs': '${e.value.jobs}'})
          .toList(),
      'week_wise': weekMap.entries
          .map((e) => {'week': e.key, 'earnings': e.value.earnings.toStringAsFixed(0), 'jobs': '${e.value.jobs}'})
          .toList(),
      'month_wise': monthMap.entries
          .map((e) => {'month': e.key, 'earnings': e.value.earnings.toStringAsFixed(0), 'jobs': '${e.value.jobs}'})
          .toList(),
    };
  }

  /// Monthly stats for reports screen (charts + cards).
  static Map<String, dynamic> monthlyStats(List<dynamic> transactions, DateTime month) {
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final earnings = List<double>.filled(lastDay, 0.0);
    final jobs = List<int>.filled(lastDay, 0);
    final labels = List.generate(lastDay, (i) => (i + 1).toString());

    double totalEarnings = 0;
    int totalCount = 0;
    int completedCount = 0;

    for (final raw in transactions) {
      if (raw is! Map) continue;
      final tx = Map<String, dynamic>.from(raw);
      final date = parseDate(tx);
      if (date == null || date.year != month.year || date.month != month.month) continue;
      if (isPayout(tx)) continue;

      totalCount++;
      if (countsForEarnings(tx)) {
        completedCount++;
        final amt = parseAmount(tx);
        final dayIdx = date.day - 1;
        earnings[dayIdx] += amt;
        jobs[dayIdx] += 1;
        totalEarnings += amt;
      }
    }

    return {
      'earnings': earnings,
      'jobs': jobs,
      'labels': labels,
      'totalJobs': totalCount,
      'completedJobs': completedCount,
      'totalEarnings': totalEarnings,
      'completionRate': totalCount > 0 ? (completedCount / totalCount * 100).round() : 0,
    };
  }

  static List<dynamic> filterHistory(List<dynamic> transactions) {
    return transactions.where((raw) {
      if (raw is! Map) return false;
      return showInEarningsHistory(Map<String, dynamic>.from(raw));
    }).toList();
  }

  static DateTime _startOfWeek(DateTime date) => startOfWeekLocal(date);

  static bool isSameWeek(DateTime a, DateTime b) {
    final sa = _startOfWeek(a);
    final sb = _startOfWeek(b);
    return sa.year == sb.year && sa.month == sb.month && sa.day == sb.day;
  }

  static bool isInSelectedPeriod(DateTime date, String period, DateTime now) {
    final d = localDateOnly(date);
    final n = localDateOnly(now);
    switch (period) {
      case 'Daily':
        return d.year == n.year && d.month == n.month && d.day == n.day;
      case 'Weekly':
        return isSameWeek(d, n);
      case 'Monthly':
        return d.year == n.year && d.month == n.month;
      case 'Yearly':
        return d.year == n.year;
      default:
        return true;
    }
  }

  /// Today + this-month totals for the home dashboard cards.
  static Map<String, num> homePeriodStats(
    List<Map<String, dynamic>> records,
    DateTime now,
  ) {
    int todayWork = 0;
    double todayEarn = 0;
    int monthWork = 0;
    double monthEarn = 0;

    for (final r in records) {
      if (!countsForEarnings(r)) continue;
      final date = parseLocalDate(r);
      if (date == null) continue;
      final amt = parseAmount(r);

      if (isInSelectedPeriod(date, 'Daily', now)) {
        todayWork++;
        todayEarn += amt;
      }
      if (isInSelectedPeriod(date, 'Monthly', now)) {
        monthWork++;
        monthEarn += amt;
      }
    }

    return {
      'todayWork': todayWork,
      'todayEarn': todayEarn,
      'monthWork': monthWork,
      'monthEarn': monthEarn,
    };
  }

  /// Bookings for distribution chart — all non-cancelled jobs by booking date.
  static bool isCancelledBooking(Map<String, dynamic> job) {
    final status = bookingStatus(job);
    return status == 'cancelled' ||
        status == 'rejected' ||
        status == 'failed' ||
        status == 'canceled';
  }

  static Map<String, dynamic> bookingAsChartRecord(Map<String, dynamic> job) {
    return {
      'booking_id': job['booking_id'] ?? job['id'],
      'id': job['id'] ?? job['booking_id'],
      'final_amount': job['final_amount'] ?? job['amount'] ?? job['price'] ?? job['total_amount'] ?? '0',
      'amount': job['amount'] ?? job['final_amount'] ?? job['price'] ?? '0',
      'status': job['status'] ?? job['booking_status'],
      'type': 'booking',
      'booking_date': job['booking_date'] ?? job['date'],
      'created_at': job['created_at'] ?? job['booking_date'] ?? job['date'],
      'updated_at': job['updated_at'],
      'completed_at': job['completed_at'],
      'service_name': job['service_name'],
      'sub_service_name': job['sub_service_name'],
      'user_name': job['user_name'],
    };
  }

  /// All in-progress + completed bookings for booking-count charts (by booking date).
  static List<Map<String, dynamic>> mergeBookingChartRecords({
    required List<dynamic> activeBookings,
    required List<dynamic> completedBookings,
    List<dynamic> newBookings = const [],
  }) {
    final records = <Map<String, dynamic>>[];
    final seenIds = <String>{};

    for (final raw in [...newBookings, ...activeBookings, ...completedBookings]) {
      if (raw is! Map) continue;
      final job = Map<String, dynamic>.from(raw);
      if (isCancelledBooking(job)) continue;
      final id = recordId(job);
      if (id != null && seenIds.contains(id)) continue;
      records.add(bookingAsChartRecord(job));
      if (id != null) seenIds.add(id);
    }

    return records;
  }

  /// Prefer scheduled booking date for distribution charts.
  static DateTime? parseBookingChartDate(Map<String, dynamic> record) {
    for (final key in [
      'booking_date',
      'date',
      'created_at',
      'updated_at',
      'completed_at',
    ]) {
      final raw = record[key];
      if (raw == null || raw.toString().trim().isEmpty) continue;
      try {
        return localDateOnly(DateTime.parse(raw.toString()));
      } catch (_) {}
    }
    return parseLocalDate(record);
  }

  static int presentPeriodChartIndex(String period, List<String> labels, {DateTime? now}) {
    if (labels.isEmpty) return 0;
    final n = localDateOnly(now ?? DateTime.now());
    switch (period) {
      case 'Daily':
        return (n.day - 1).clamp(0, labels.length - 1);
      case 'Weekly':
        final weekStart = startOfWeekLocal(n);
        return n.difference(weekStart).inDays.clamp(0, labels.length - 1);
      case 'Monthly':
        return (n.month - 1).clamp(0, labels.length - 1);
      case 'Yearly':
        final yearLabel = n.year.toString();
        final idx = labels.indexWhere(
          (label) => label == yearLabel || label == '$yearLabel*',
        );
        return idx >= 0 ? idx : labels.length - 1;
      default:
        return 0;
    }
  }
  /// Charts + period totals for Earnings screen (Daily / Weekly / Monthly / Yearly).
  static Map<String, dynamic> buildEarningsViewData(
    List<Map<String, dynamic>> earningRecords,
    String period, {
    List<Map<String, dynamic>>? bookingRecords,
  }) {
    final bookings = bookingRecords ?? earningRecords;
    final now = DateTime.now();
    double overallTotal = 0;
    int overallJobs = 0;

    for (final r in earningRecords) {
      overallTotal += parseAmount(r);
    }
    overallJobs = bookings.length;

    double periodTotal = 0;
    int periodJobs = 0;
    for (final r in earningRecords) {
      final date = parseLocalDate(r);
      if (date == null || !isInSelectedPeriod(date, period, now)) continue;
      periodTotal += parseAmount(r);
    }
    for (final r in bookings) {
      final date = parseBookingChartDate(r);
      if (date == null || !isInSelectedPeriod(date, period, now)) continue;
      periodJobs++;
    }

    final labels = <String>[];
    final earningsValues = <double>[];
    final jobsValues = <double>[];

    if (period == 'Daily') {
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      for (int day = 1; day <= daysInMonth; day++) {
        labels.add(day == now.day ? 'Today' : day.toString());
        double e = 0;
        int j = 0;
        for (final r in earningRecords) {
          final date = parseLocalDate(r);
          if (date == null) continue;
          if (date.year == now.year && date.month == now.month && date.day == day) {
            e += parseAmount(r);
          }
        }
        for (final r in bookings) {
          final date = parseBookingChartDate(r);
          if (date == null) continue;
          if (date.year == now.year && date.month == now.month && date.day == day) {
            j++;
          }
        }
        earningsValues.add(e);
        jobsValues.add(j.toDouble());
      }
    } else if (period == 'Weekly') {
      final weekStart = startOfWeekLocal(now);
      for (int i = 0; i < 7; i++) {
        final day = weekStart.add(Duration(days: i));
        final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
        labels.add(isToday ? 'Today' : DateFormat('E\nd').format(day));
        double e = 0;
        int j = 0;
        for (final r in earningRecords) {
          final date = parseLocalDate(r);
          if (date == null) continue;
          if (date.year == day.year && date.month == day.month && date.day == day.day) {
            e += parseAmount(r);
          }
        }
        for (final r in bookings) {
          final date = parseBookingChartDate(r);
          if (date == null) continue;
          if (date.year == day.year && date.month == day.month && date.day == day.day) {
            j++;
          }
        }
        earningsValues.add(e);
        jobsValues.add(j.toDouble());
      }
    } else if (period == 'Monthly') {
      const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      for (int m = 1; m <= 12; m++) {
        labels.add(m == now.month ? '${monthNames[m - 1]}*' : monthNames[m - 1]);
        double e = 0;
        int j = 0;
        for (final r in earningRecords) {
          final date = parseLocalDate(r);
          if (date == null) continue;
          if (date.year == now.year && date.month == m) {
            e += parseAmount(r);
          }
        }
        for (final r in bookings) {
          final date = parseBookingChartDate(r);
          if (date == null) continue;
          if (date.year == now.year && date.month == m) {
            j++;
          }
        }
        earningsValues.add(e);
        jobsValues.add(j.toDouble());
      }
    } else if (period == 'Yearly') {
      final years = <int>{now.year};
      for (final r in [...earningRecords, ...bookings]) {
        final date = parseBookingChartDate(r);
        if (date != null) years.add(date.year);
      }
      final sortedYears = years.toList()..sort();
      if (sortedYears.length > 6) {
        sortedYears.removeRange(0, sortedYears.length - 6);
      }
      for (final y in sortedYears) {
        labels.add(y == now.year ? '$y*' : y.toString());
        double e = 0;
        int j = 0;
        for (final r in earningRecords) {
          final date = parseLocalDate(r);
          if (date == null) continue;
          if (date.year == y) {
            e += parseAmount(r);
          }
        }
        for (final r in bookings) {
          final date = parseBookingChartDate(r);
          if (date == null) continue;
          if (date.year == y) {
            j++;
          }
        }
        earningsValues.add(e);
        jobsValues.add(j.toDouble());
      }
    } else {
      // Total — all-time by year
      periodTotal = overallTotal;
      periodJobs = overallJobs;
      final years = <int>{};
      for (final r in bookings) {
        final date = parseBookingChartDate(r);
        if (date != null) years.add(date.year);
      }
      if (years.isEmpty) years.add(now.year);
      final sortedYears = years.toList()..sort();
      for (final y in sortedYears) {
        labels.add(y.toString());
        double e = 0;
        int j = 0;
        for (final r in earningRecords) {
          final date = parseLocalDate(r);
          if (date == null) continue;
          if (date.year == y) {
            e += parseAmount(r);
          }
        }
        for (final r in bookings) {
          final date = parseBookingChartDate(r);
          if (date == null) continue;
          if (date.year == y) {
            j++;
          }
        }
        earningsValues.add(e);
        jobsValues.add(j.toDouble());
      }
    }

    return {
      'totalEarnings': periodTotal,
      'totalJobs': periodJobs,
      'overallTotal': overallTotal,
      'overallJobs': overallJobs,
      'labels': labels,
      'earningsValues': earningsValues,
      'jobsValues': jobsValues,
    };
  }
}

class _Bucket {
  double earnings = 0;
  int jobs = 0;

  void add(double amount) {
    earnings += amount;
    jobs++;
  }
}
