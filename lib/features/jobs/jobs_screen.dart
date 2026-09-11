import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';
import 'package:tapasya_vendor_app/services/api_service.dart';
import 'package:tapasya_vendor_app/features/auth/registration/registration_state.dart';
import 'package:tapasya_vendor_app/core/utils/transaction_stats_utils.dart';
import 'package:tapasya_vendor_app/features/home/vendor_provider.dart';
import 'package:tapasya_vendor_app/services/socket_service.dart';

class JobsScreen extends StatefulWidget {
  final int initialIndex;
  const JobsScreen({super.key, this.initialIndex = 0});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  // Pagination & Filtering (Local UI state)
  String _selectedCategory = 'All';
  String _sortBy = 'Newest'; // Newest, Oldest

  @override
  void initState() {
    super.initState();
    
    // 🔥 INITIAL LOAD: Fetch everything via Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VendorProvider>().fetchAllJobs();
      context.read<VendorProvider>().fetchVendorServices();
    });
    SocketService.listenForJobTaken((data) {
      if (mounted) context.read<VendorProvider>().fetchAllJobs();
    });

    // 🔥 REAL-TIME SYNC: Refresh everything when ANY job is updated (accepted, started, completed, rejected)
    SocketService.listenForJobUpdate((data) {
      if (mounted) context.read<VendorProvider>().fetchAllJobs();
    });

    // Fetch dynamic vendor services for the filter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VendorProvider>().fetchVendorServices();
    });
  }

  Future<void> _fetchJobsForStatus(String tabKey, {bool isLoadMore = false}) async {
    if (mounted) {
      context.read<VendorProvider>().fetchJobsForStatus(tabKey, isLoadMore: isLoadMore);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialIndex,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Column(
          children: [
            // 1. PREMIUM HEADER WITH INTEGRATED TABS
            _buildPremiumHeader(),

            // 2. FILTER & SORT ROW
            _buildFilterAndSortRow(),

            // 3. JOB LISTING (PAGINATED)
            Expanded(
              child: TabBarView(
                children: [
                  _buildJobList('active'),
                  _buildJobList('completed'),
                  _buildJobList('cancelled'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _BubbleBackgroundPainter())),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  const Text(
                    "My Jobs", 
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)
                  ),
                  const SizedBox(height: 24),
                
                // TAB BAR (PILL STYLE)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: TabBar(
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                    ),
                    labelColor: AppTheme.primaryColor,
                    unselectedLabelColor: Colors.white70,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    tabs: const [
                      Tab(text: "In Progress"),
                      Tab(text: "Completed"),
                      Tab(text: "Cancelled"),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ],
    ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildFilterAndSortRow() {
    return Consumer<VendorProvider>(
      builder: (context, vendorProv, _) {
        // Dynamic categories from vendor services (Now using Sub-Services for granularity)
        final List<String> dynamicCategories = ['All'];
        for (var service in vendorProv.vendorServices) {
           final name = service['sub_service_name'] ?? '';
           if (name.isNotEmpty && !dynamicCategories.contains(name)) {
             dynamicCategories.add(name);
           }
        }

        return Column(
          children: [
             Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Row(
                children: [
                  const Icon(Icons.filter_list_rounded, color: Colors.grey, size: 16),
                  const SizedBox(width: 8),
                   const Text("Filter by Service Type", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF1B263B))),
                  const Spacer(),
                  _buildSortDropdown(),
                ],
              ),
            ),
            Container(
              height: 50,
              width: double.infinity,
              alignment: Alignment.centerLeft,
              margin: const EdgeInsets.only(top: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: dynamicCategories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: 250.ms,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade600,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        );
      },
    ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildSortDropdown() {
    return PopupMenuButton<String>(
      onSelected: (val) {
        HapticFeedback.lightImpact();
        setState(() => _sortBy = val);
      },
      offset: const Offset(0, 50),
      elevation: 12,
      color: Colors.white,
      shadowColor: Colors.black.withOpacity(0.18),
      constraints: const BoxConstraints(minWidth: 230),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.withOpacity(0.12)),
      ),
      itemBuilder: (context) => [
        _buildSortItem(
          value: 'Newest',
          icon: Icons.arrow_downward_rounded,
          title: 'Newest first',
          subtitle: 'Latest jobs on top',
        ),
        const PopupMenuItem<String>(
          enabled: false,
          height: 1,
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(height: 1),
        ),
        _buildSortItem(
          value: 'Oldest',
          icon: Icons.arrow_upward_rounded,
          title: 'Oldest first',
          subtitle: 'Earliest jobs on top',
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_sortBy, style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w900, fontSize: 13)),
            const SizedBox(width: 6),
            const Icon(Icons.unfold_more_rounded, color: AppTheme.primaryColor, size: 16),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildSortItem({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final bool selected = _sortBy == value;
    return PopupMenuItem<String>(
      value: value,
      padding: EdgeInsets.zero,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor.withOpacity(0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected ? AppTheme.primaryColor.withOpacity(0.15) : Colors.grey.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: selected ? AppTheme.primaryColor : Colors.grey.shade500,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? AppTheme.primaryColor : const Color(0xFF1B1B1F),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle_rounded, size: 20, color: AppTheme.primaryColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildJobList(String tabKey) {
    final venderProv = context.watch<VendorProvider>();
    final isLoading = venderProv.isLoadingByStatus[tabKey] ?? false;
    final allJobs = venderProv.jobsByStatus[tabKey] ?? [];
    final completedIds = tabKey == 'active'
        ? venderProv.jobsByStatus['completed']
                ?.map((job) => (job is Map ? (job['id'] ?? job['booking_id']) : null)?.toString() ?? '')
                .where((id) => id.isNotEmpty)
                .toSet() ??
            <String>{}
        : <String>{};
    final cancelledIds = tabKey == 'active'
        ? venderProv.jobsByStatus['cancelled']
                ?.map((job) => (job is Map ? (job['id'] ?? job['booking_id']) : null)?.toString() ?? '')
                .where((id) => id.isNotEmpty)
                .toSet() ??
            <String>{}
        : <String>{};
    final jobsForTab = tabKey == 'active'
        ? allJobs.where((job) {
            if (job is! Map) return false;
            final jobMap = Map<String, dynamic>.from(job);
            final id = (jobMap['id'] ?? jobMap['booking_id'])?.toString() ?? '';
            if (id.isNotEmpty && (completedIds.contains(id) || cancelledIds.contains(id))) {
              return false;
            }
            return TransactionStatsUtils.isInProgressBooking(jobMap);
          }).toList()
        : allJobs;

    if (isLoading && jobsForTab.isEmpty) {
      return _buildShimmerList();
    }
    
    // 1. Filtering Logic
    var filteredJobs = _selectedCategory == 'All' 
        ? List.from(jobsForTab)
        : jobsForTab.where((j) {
            // 🔥 Use Top-Level Keys for Accurate Filtering
            final String name = (j['sub_service_name'] ?? j['service_name'] ?? '').toString();
            return name.toLowerCase() == _selectedCategory.toLowerCase();
          }).toList();

    // 2. Sorting Logic
    if (_sortBy == 'Newest') {
      filteredJobs.sort((a, b) => (b['id'] ?? 0).compareTo(a['id'] ?? 0));
    } else {
      filteredJobs.sort((a, b) => (a['id'] ?? 0).compareTo(b['id'] ?? 0));
    }

    if (filteredJobs.isEmpty) {
      return _buildEmptyState(tabKey);
    }

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () => _fetchJobsForStatus(tabKey),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
        itemCount: filteredJobs.length + (filteredJobs.length >= 10 ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          if (index == filteredJobs.length) {
            return _buildLoadMoreButton(tabKey);
          }
          final job = filteredJobs[index];
          return _buildPremiumJobCard(job, tabKey);
        },
      ),
    );
  }

  Widget _buildPremiumJobCard(Map<String, dynamic> job, String tabKey) {
    final services = job['services_list'] ?? job['services'] ?? [];
    final name = job['user_name'] ?? job['customer']?['full_name'] ?? 'Customer';
    final id = job['id']?.toString() ?? job['booking_id']?.toString() ?? '';
    final time = job['time_slot'] ?? 'Scheduled';
    final location = job['address'] is Map ? (job['address']['address_line1'] ?? 'Location N/A') : job['address'] ?? 'Location N/A';
    
    // 🔥 DYNAMIC SERVICE EXTRACTION
    final String serviceName = job['service_name'] ?? 'Service';
    final String subServiceName = job['sub_service_name'] ?? '';
    final String dateStr = job['booking_date'] ?? job['date'] ?? '';
    
    String formattedDate = "Recent mission";
    if (dateStr.isNotEmpty) {
      try {
        final dt = DateTime.parse(dateStr);
        final months = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        formattedDate = "${dt.day} ${months[dt.month]}, ${dt.year}";
      } catch (_) {
        formattedDate = dateStr.contains('T') ? dateStr.split('T').first : dateStr;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 12)),
          BoxShadow(color: AppTheme.primaryColor.withOpacity(0.02), blurRadius: 30, offset: const Offset(0, 15)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // 1. PREMIUM HEADER LAYER
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          tabKey == 'new' ? Icons.bolt_rounded : (tabKey == 'completed' ? Icons.verified_rounded : (tabKey == 'cancelled' ? Icons.cancel_rounded : Icons.pending_actions_rounded)),
                          color: tabKey == 'new' ? Colors.orange : (tabKey == 'completed' ? Colors.green : (tabKey == 'cancelled' ? Colors.red : Colors.blue)),
                          size: 20
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name, 
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1B263B), letterSpacing: -0.6),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    subServiceName.isNotEmpty ? "$serviceName - $subServiceName" : serviceName, 
                                    style: TextStyle(color: AppTheme.primaryColor.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.2), 
                                    maxLines: 1, overflow: TextOverflow.ellipsis
                                  )
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (tabKey == 'new')
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFF57C00)]),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
                          ),
                          child: const Text("NEW", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 9)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // 2. STAGGERED INFO CONTAINER
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade100, width: 1),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.location_on_rounded, color: Colors.blueAccent, size: 12),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("SERVICE LOCATION", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.8)),
                                  const SizedBox(height: 1),
                                  Text(
                                    tabKey == 'completed' && location.length > 15 
                                      ? "${location.substring(0, 12)}... xxxxxxx" 
                                      : location, 
                                    style: const TextStyle(color: Color(0xFF1B263B), fontSize: 11, fontWeight: FontWeight.w700),
                                    maxLines: 1, overflow: TextOverflow.ellipsis
                                  ),
                                ],
                              ),
                            ),
                            if (tabKey == 'completed')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade100)),
                                child: Text(
                                  "₹${job['final_amount'] ?? job['amount'] ?? job['total'] ?? job['price'] ?? job['total_amount'] ?? '0'}", 
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.green.shade700)
                                ),
                              ),
                          ],
                        ),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider(height: 1, color: Color(0xFFEEEEEE))),
                        // 🟢 DEBUG LOGS 🛡️
                        if (tabKey == 'completed') 
                          () { debugPrint("🔥 COMPLETED JOB DATA (JOBS SCREEN): $job"); return const SizedBox.shrink(); }(),
                        // 🟢 MINI STATUS TIMELINE (ONLY FOR COMPLETED)
                        if (tabKey == 'completed') ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildMiniStep("Requested", true),
                                _buildMiniLine(true),
                                _buildMiniStep("Accepted", true),
                                _buildMiniLine(true),
                                _buildMiniStep("Started", true),
                                _buildMiniLine(true),
                                _buildMiniStep("Completed", true),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.calendar_month_rounded, color: Colors.deepPurpleAccent, size: 12),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("MISSION WINDOW", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.8)),
                                  const SizedBox(height: 1),
                                  Row(
                                    children: [
                                      Text(formattedDate, style: const TextStyle(color: Color(0xFF1B263B), fontSize: 11, fontWeight: FontWeight.w700)),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: const Color(0xFF673AB7).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                        child: Text(time, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Color(0xFF673AB7))),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // 3. CINEMATIC ACTION FOOTER (Hided if Completed/Cancelled)
            if (tabKey == 'new' || tabKey == 'active')
              Column(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7E57C2), // Deep Lavender/Purple Mid-Dark
                      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1)),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => context.push('/jobs/details/$id', extra: job),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "VIEW MISSION DETAILS",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.0),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_right_alt_rounded, color: Colors.white, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: tabKey == 'new' ? const Color(0xFFFB8C00) : const Color(0xFF43A047), // Orange vs Green
                      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1)),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _handleJobAction(job, tabKey),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                tabKey == 'new' ? "ACCEPT MISSION" : (job['status'] == 'accepted' ? "START MISSION" : "COMPLETE SERVICE"),
                                style: const TextStyle(
                                  color: Colors.white, 
                                  fontWeight: FontWeight.w900, 
                                  fontSize: 13,
                                  letterSpacing: 1.0
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward_ios_rounded, 
                                color: Colors.white, 
                                size: 13
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            // COLORED FOOTER FOR TERMINAL STATUSES (No Button)
            if (tabKey == 'completed' || tabKey == 'cancelled')
              Container(
                height: 12, width: double.infinity,
                decoration: BoxDecoration(color: tabKey == 'completed' ? const Color(0xFF43A047) : Colors.red.shade600),
              ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
  }

  Widget _buildMiniStep(String label, bool active) {
    return Column(
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: active ? const Color(0xFF43A047) : Colors.grey.shade300),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: active ? const Color(0xFF1B263B) : Colors.grey.shade400)),
      ],
    );
  }

  Widget _buildMiniLine(bool active) {
    return Expanded(
      child: Container(
        height: 2, margin: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
        decoration: BoxDecoration(color: active ? const Color(0xFF43A047).withOpacity(0.5) : Colors.grey.shade200, borderRadius: BorderRadius.circular(1)),
      ),
    );
  }

  Widget _buildLoadMoreButton(String tabKey) {
    return InkWell(
      onTap: () => _fetchJobsForStatus(tabKey, isLoadMore: true),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: const Text("Load More Jobs", style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryColor, fontSize: 14)),
      ),
    );
  }

  Widget _buildEmptyState(String tabKey) {
    String message;
    String asset;
    switch(tabKey) {
      case 'new': message = "No New Job Requests!"; asset = 'assets/images/no-new-job.png'; break;
      case 'active': message = "No Active Jobs Found!"; asset = 'assets/images/no-active-jobs.png'; break;
      case 'completed': message = "No Completed Jobs Yet!"; asset = 'assets/images/no-completed-job.png'; break;
      default: message = "No Cancelled Jobs!"; asset = 'assets/images/no-jobs-cancelled.png';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(asset, width: 250, height: 250).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(color: Color(0xFF1B263B), fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 50),
            child: Text(
              "Keep up the great work! Your new opportunities will appear here automatically.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.5, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 3,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) => Container(
        height: 180,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1.5.seconds, color: Colors.grey.shade50),
    );
  }

  Future<void> _handleJobAction(Map<String, dynamic> job, String tabKey) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? context.read<RegistrationState>().authToken;
    final vendorId = job['vendor_id'] ?? job['assign_vendor_id'] ?? '';
    final bookingId = job['id'] ?? job['booking_id'] ?? '';

    String action = tabKey == 'new' ? "ACCEPTED" : (job['status'] == 'accepted' ? "STARTED" : "COMPLETED");

    final res = await ApiService().bookingAction(token, bookingId, vendorId, action);

    if (mounted && res['success'] == true) {
      if (action == 'COMPLETED') {
        await context.read<VendorProvider>().refreshJobsAfterComplete(bookingId.toString());
      } else {
        context.read<VendorProvider>().fetchAllJobs();
      }
    }
  }
}

class _BubbleBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.05)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.2), 30, paint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.15), 50, paint);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.7), 60, paint);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.8), 40, paint);
    final strokePaint = Paint()..color = Colors.white.withOpacity(0.03)..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.5), 70, strokePaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
