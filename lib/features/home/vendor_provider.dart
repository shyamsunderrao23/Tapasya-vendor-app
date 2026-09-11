import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tapasya_vendor_app/models/vendor_model.dart';
import 'package:tapasya_vendor_app/services/api_service.dart';
import 'package:tapasya_vendor_app/services/socket_service.dart';
import 'package:tapasya_vendor_app/core/utils/notification_helper.dart';
import 'package:tapasya_vendor_app/core/utils/transaction_stats_utils.dart';

class VendorProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  VendorProfile? _profile;
  bool _isLoading = false;
  String? _error;
  bool _isMagicFabExpanded = false;
  
  // 🔥 PERSISTENT VERIFICATION LOCK
  bool _isFullyVerifiedCache = false;
  List<VendorDocument> _lockedDocuments = [];

  VendorProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isMagicFabExpanded => _isMagicFabExpanded;

  // --- Document Verification Status ---
  bool get hasDocumentError => _statusError?.contains('documents') == true;

  bool get isFullyVerified {
    // 🛡️ LOCK CHECK: If we already confirmed verification this session, don't re-lock it!
    if (_isFullyVerifiedCache) return true;

    // 1. Check actual document list from profile
    if (_profile == null) {
      debugPrint("🔍 [VERIFY] Profile is NULL");
      return false;
    }
    
    final docs = _profile!.documents;
    if (docs.isEmpty) {
      debugPrint("🔍 [VERIFY] Docs list is EMPTY");
      return false;
    }
    
    // 2. Strict Check: Both AADHAR and PAN must be APPROVED or VERIFIED
    final bool hasAadharApproved = docs.any((d) {
      final type = d.documentType.toUpperCase();
      final status = d.verificationStatus.toUpperCase();
      final isAadhar = type.contains('ADHAR') || type.contains('AADHAR') || type.contains('AADHAAR');
      final isStatusOk = status == 'APPROVED' || status == 'VERIFIED';
      return isAadhar && isStatusOk;
    });
    
    final bool hasPanApproved = docs.any((d) {
      final type = d.documentType.toUpperCase();
      final status = d.verificationStatus.toUpperCase();
      final isPan = type == 'PAN' || type.contains('PAN_CARD');
      final isStatusOk = status == 'APPROVED' || status == 'VERIFIED';
      return isPan && isStatusOk;
    });

    debugPrint("🔍 [VERIFY] Aadhar Approved: $hasAadharApproved, PAN Approved: $hasPanApproved");
    for (var d in docs) {
      debugPrint("   📄 Doc: ${d.documentType} | Status: ${d.verificationStatus}");
    }
    
    // If documents are physically approved, we are verified!
    if (hasAadharApproved && hasPanApproved) {
      if (!_isFullyVerifiedCache) {
        debugPrint("✅ [VERIFY] SUCCESS: Newly Verified! Locking status.");
        _isFullyVerifiedCache = true; // 🛡️ LOCK IT FOREVER THIS SESSION!
      }
      return true;
    }
    
    // 🔥 EMERGENCY BYPASS: If we see 2 approved docs of any type, let them in!
    final approvedCount = docs.where((d) => 
      d.verificationStatus.toUpperCase() == 'APPROVED' || 
      d.verificationStatus.toUpperCase() == 'VERIFIED'
    ).length;
    
    if (approvedCount >= 2) {
      debugPrint("🚀 [VERIFY] EMERGENCY BYPASS TRIGGERED: Found $approvedCount approved docs.");
      _isFullyVerifiedCache = true; // 🛡️ LOCK IT!
      return true;
    }

    // 3. Fallback to server-side status error string if documents aren't approved yet
    if (hasDocumentError) {
      debugPrint("🔍 [VERIFY] Falling back to hasDocumentError: true");
      return false;
    }
    
    return false;
  }

  // --- Pro Dynamic Data ---
  Map<String, dynamic>? _profileFullData;
  Map<String, dynamic>? _earningsData;
  List<dynamic> _transactionsData = [];

  Map<String, dynamic>? _performanceData;
  List<dynamic> _availabilityData = [];

  Map<String, dynamic>? get profileFullData => _profileFullData;
  Map<String, dynamic>? get earningsData => _earningsData;
  List<dynamic> get transactionsData => _transactionsData;
  Map<String, dynamic>? get performanceData => _performanceData;
  List<dynamic> get availabilityData => _availabilityData;
  Map<String, dynamic>? _reviewsFullData;
  Map<String, dynamic>? get reviewsFullData => _reviewsFullData;

  // --- Jobs (Bookings) Management ---
  final Map<String, List<dynamic>> _jobsByStatus = {
    'new': [],
    'active': [],
    'completed': [],
    'cancelled': [],
  };
  final Map<String, bool> _isLoadingByStatus = {
    'new': false,
    'active': false,
    'completed': false,
    'cancelled': false,
  };
  final Map<String, int> _currentPageByStatus = {
    'new': 1,
    'active': 1,
    'completed': 1,
    'cancelled': 1,
  };

  Map<String, List<dynamic>> get jobsByStatus => _jobsByStatus;
  Map<String, bool> get isLoadingByStatus => _isLoadingByStatus;

  void setMagicFabExpanded(bool value) {
    if (_isMagicFabExpanded != value) {
      _isMagicFabExpanded = value;
      notifyListeners();
    }
  }

  Future<void> _syncAlertPrefs() async {
    if (_profile != null) {
      await NotificationHelper.persistOnlineStatus(_profile!.vendor.activeStatus);
      await NotificationHelper.persistJobMode(_profile!.vendor.jobMode);
    }
  }

  void clearSession() {
    _profile = null;
    _error = null;
    _statusError = null;
    _dashboardData = null;
    _profileFullData = null;
    _earningsData = null;
    _transactionsData = [];
    _performanceData = null;
    _availabilityData = [];
    _reviewsFullData = null;
    _isFullyVerifiedCache = false;
    _lockedDocuments = [];
    _jobsByStatus.updateAll((_, __) => []);
    _isLoading = false;
    _isInitializing = false;
    notifyListeners();
  }

  /// Full data reload (used after login and on home mount).
  /// [clearFirst] wipes stale session data first — set true for a fresh login,
  /// false to silently refresh while keeping current data on screen.
  Future<void> refreshAfterLogin(String token, {bool clearFirst = true}) async {
    debugPrint('🔄 [VENDOR_PROVIDER] Home reload (clearFirst: $clearFirst)...');
    if (clearFirst) clearSession();
    _isInitializing = false;

    await initialLoad(token);

    await Future.wait([
      fetchAllJobs(),
      fetchEarnings(),
      fetchPerformance(),
      fetchVendorServices(),
      fetchReviewsFull(),
      fetchNotifications(),
    ]);

    notifyListeners();
    debugPrint('✅ [VENDOR_PROVIDER] Home reload done');
  }

  // Future<void> fetchVendorProfile([String? providedToken]) async {
  //   _isLoading = true;
  //   _error = null;
  //   notifyListeners();

  //   try {
  //     String token = providedToken ?? '';
      
  //     if (token.isEmpty) {
  //       final prefs = await SharedPreferences.getInstance();
  //       token = prefs.getString('auth_token') ?? '';
  //     }

  //     if (token.isEmpty) {
  //       _error = "Authentication token not found";
  //       _isLoading = false;
  //       notifyListeners();
  //       return;
  //     }

  //     final response = await _apiService.getMyVendor(token);
      
  //     if (response != null && response['success'] == true) {
  //       _profile = VendorProfile.fromMap(response['data']);
  //       _error = null;
  //     } else {
  //       _error = "Failed to fetch vendor profile (Invalid token)";
  //     }
  //   } catch (e) {
  //     _error = "An error occurred: $e";
  //   } finally {
  //     _isLoading = false;
  //     notifyListeners();
  //   }
  // }

  bool _isInitializing = false;
  bool get isInitializing => _isInitializing;

  Future<void> initialLoad(String token) async {
    if (_isInitializing) return;
    _isInitializing = true;
    _isLoading = true;
    _error = null;
    notifyListeners();

    debugPrint("🚀 [VENDOR_PROVIDER] Atomic Load Started...");

    try {
      // 1. Fetch Profile and Full Stats in parallel for speed
      final results = await Future.wait([
        _apiService.getMyVendor(token),
        _apiService.getProfileFull(token),
        _apiService.getDashboard(token),
        _apiService.getTransactions(token),
      ]);

      final profileRes = results[0] as Map<String, dynamic>?;
      final fullProfileRes = results[1] as Map<String, dynamic>;
      final dashRes = results[2] as Map<String, dynamic>;
      final txRes = results[3] as Map<String, dynamic>;

      // Hydrate identity from whichever source worked
      if (fullProfileRes['success'] == true) {
        _profileFullData = fullProfileRes['data'];
        if (fullProfileRes['data']['vendor'] != null) {
          // 🛡️ PERSISTENCE: Use locked documents or existing ones to prevent wipe
          final existingDocs = _lockedDocuments.isNotEmpty ? _lockedDocuments : _profile?.documents;
          _profile = VendorProfile.fromMap(fullProfileRes['data'], existingDocuments: existingDocs);
        }
      } else if (profileRes != null && profileRes['success'] == true) {
        final existingDocs = _lockedDocuments.isNotEmpty ? _lockedDocuments : _profile?.documents;
        _profile = VendorProfile.fromMap(profileRes['data'], existingDocuments: existingDocs);
      }

      if (dashRes['success'] == true) _dashboardData = dashRes['data'];
      if (txRes['success'] == true) _transactionsData = txRes['data'] ?? [];

      // Only set a fatal error if we have NO profile at all and NO business error
      if (_profile == null) {
        final String msg = profileRes?['message'] ?? fullProfileRes['message'] ?? "Connection failed";
        if (!msg.contains('documents')) {
          _error = "Failed to fetch vendor profile (Invalid token)";
        } else {
          _statusError = msg;
        }
      } else {
        _error = null;
        _statusError = null;
      }

    } catch (e) {
      debugPrint("Startup Load Exception: $e");
      _error = "Startup Load Error: $e";
    } finally {
      _isLoading = false;
      _isInitializing = false;
      await _syncAlertPrefs();
      notifyListeners();
    }
  }

  /// 🔥 MASTER BOOT SYNC: Called by Splash Screen to ensure zero-flicker verification
  Future<void> atomicBootSync(String token) async {
    _isLoading = true;
    _isInitializing = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint("🚀 [BOOT_SYNC] Starting atomic verification...");
      // Fetch both profile and dashboard in parallel for speed
      final results = await Future.wait([
        _apiService.getMyVendor(token),
        _apiService.getDashboard(token),
      ]);

      final profileRes = results[0] as Map<String, dynamic>?;
      if (profileRes != null && profileRes['success'] == true) {
        // 🛡️ Use locked docs if available
        final existingDocs = _lockedDocuments.isNotEmpty ? _lockedDocuments : _profile?.documents;
        _profile = VendorProfile.fromMap(profileRes['data'], existingDocuments: existingDocs);
        
        // Lock them in if found
        if (_profile!.documents.isNotEmpty && _lockedDocuments.isEmpty) {
          _lockedDocuments = List.from(_profile!.documents);
          debugPrint("🔒 [BOOT_SYNC] Found & Locked ${_lockedDocuments.length} documents.");
        }
      }

      final dashRes = results[1] as Map<String, dynamic>?;
      if (dashRes != null && dashRes['success'] == true) {
        _dashboardData = dashRes['data'];
      }
      
      debugPrint("✅ [BOOT_SYNC] Finished. Verified: $isFullyVerified");
    } catch (e) {
      debugPrint("❌ [BOOT_SYNC] Failed: $e");
    } finally {
      _isLoading = false;
      _isInitializing = false;
      await _syncAlertPrefs();
      notifyListeners();
    }
  }

  Future<void> fetchVendorProfile([String? providedToken]) async {
  _isLoading = true;
  _error = null;
  notifyListeners();

  try {
    String token = providedToken ?? '';

    if (token.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('auth_token') ?? '';
    }

    // 🔥 DEBUG TOKEN FROM STORAGE
    print("📦 TOKEN FROM STORAGE: $token");

    if (token.isEmpty) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    final response = await _apiService.getMyVendor(token);

    if (response != null && response['success'] == true) {
      if (response['data']['documents'] == null) {
        debugPrint("🚨 [CRITICAL] Backend response is SUCCESS but 'documents' key is MISSING from data!");
      }
      
      // 🛡️ PERSISTENCE: Carry forward existing docs if new response is missing them
      final existingDocs = _lockedDocuments.isNotEmpty ? _lockedDocuments : _profile?.documents;
      _profile = VendorProfile.fromMap(response['data'], existingDocuments: existingDocs);
      
      // 🔥 LOCK DOCUMENTS: If we finally found the docs, lock them in forever!
      if (_profile!.documents.isNotEmpty && _lockedDocuments.isEmpty) {
        _lockedDocuments = List.from(_profile!.documents);
        debugPrint("🔒 [MEMORY] Locked ${_lockedDocuments.length} documents into session memory.");
      }

      if (existingDocs != null && _profile!.documents.length == existingDocs.length) {
        debugPrint("🔍 [SYNC] Persisted ${existingDocs.length} documents into new profile.");
      }
      
      _error = null;
      _statusError = null;
    } else {
      _statusError = response?['message'] ?? "Status verification failed";
      if (_statusError!.contains('documents')) {
        _error = null;
      } else {
        _error = "Failed to fetch vendor profile (Invalid token)";
      }
    }
  } catch (e) {
    _error = "An error occurred: $e";
  } finally {
    _isLoading = false;
    await _syncAlertPrefs();
    notifyListeners();
  }
}

  // --- Dashboard Data Management ---
  Map<String, dynamic>? _dashboardData;
  bool _isDashboardLoading = false;

  Map<String, dynamic>? get dashboardData => _dashboardData;
  bool get isDashboardLoading => _isDashboardLoading;

  Future<void> fetchDashboardData([String? providedToken]) async {
    _isDashboardLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = (providedToken != null && providedToken.isNotEmpty) 
          ? providedToken 
          : (prefs.getString('auth_token') ?? '');
      
      if (token.isNotEmpty) {
        final res = await _apiService.getDashboard(token);
        debugPrint("📊 [DEBUG] RAW DASHBOARD RESPONSE: $res");
        if (res['success'] == true) {
          _dashboardData = res['data'];
          // 🔥 SYNC: Stat cards in HomeScreen use transactionsData!
          await fetchTransactions();
        }
      }
    } catch (e) {
      debugPrint("Dashboard Error: $e");
    } finally {
      _isDashboardLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchProfileFull() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      if (token.isNotEmpty) {
        final res = await _apiService.getProfileFull(token);
        if (res['success'] == true) {
          _profileFullData = res['data'];
          
          // 🔥 CORE SYNC: Update the main _profile object so the UI headers find the name/details!
          if (res['data']['vendor'] != null) {
            // 🛡️ PERSISTENCE: Preserve documents during full profile sync
            final existingDocs = _lockedDocuments.isNotEmpty ? _lockedDocuments : _profile?.documents;
            _profile = VendorProfile.fromMap(res['data'], existingDocuments: existingDocs);
            
            if (existingDocs != null) {
              debugPrint("🔍 [SYNC] Carried forward ${existingDocs.length} docs during Full Profile Sync.");
            }
            
            _error = null; // ✅ CLEAR ERROR: If we got the data, the token/session is VALID!
            debugPrint("✅ [VENDOR_PROVIDER] Core identity synchronized and error cleared.");
          }
        }
      }
    } catch (e) {
      debugPrint("Profile Full Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchEarnings() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      if (token.isNotEmpty) {
        final res = await _apiService.getMainEarnings(token);
        if (res['success'] == true) {
          _earningsData = res; 
        }
      }
    } catch (e) {
      debugPrint("Earnings Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchTransactions() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      if (token.isNotEmpty) {
        final res = await _apiService.getTransactions(token);
        if (res['success'] == true) {
          _transactionsData = res['data'] ?? [];
        }
      }
    } catch (e) {
      debugPrint("Transactions Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> setJobMode(String mode) async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      
      final res = await _apiService.updateJobMode(token, mode);
      if (res['success'] == true) {
        await fetchVendorProfile(token);
        // 🔥 SOCKET SYNC
        if (_profile != null) {
          SocketService.forceSync(_profile!.vendor.id);
        }
      }
      return res;
    } catch (e) {
      return {"success": false, "message": e.toString()};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchPerformance() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      if (token.isNotEmpty) {
        final res = await _apiService.getPerformance(token);
        if (res['success'] == true) {
          _performanceData = res['data'];
        }
      }
    } catch (e) {
      debugPrint("Performance Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAvailability() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      if (token.isNotEmpty) {
        final res = await _apiService.getAvailability(token);
        if (res['success'] == true) {
          _availabilityData = res['data'] ?? [];
        }
      }
    } catch (e) {
      debugPrint("Availability Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchReviewsFull({int? rating, int page = 1}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      if (token.isNotEmpty) {
        final res = await _apiService.getReviewsFull(token, rating: rating, page: page);
        if (res['success'] == true) {
          _reviewsFullData = res['data'];
        }
      }
    } catch (e) {
      debugPrint("Reviews Full Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> updateAvailability(List availability) async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final res = await _apiService.setAvailability(token, availability);
      if (res['success'] == true) {
        await fetchAvailability();
      }
      return res;
    } catch (e) {
      return {"success": false, "message": e.toString()};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String phone,
    required String address,
    required String email,
    String? fathersName,
    String? dob,
    String? gender,
    String? whatsapp,
    String? secondaryPhone,
    String? city,
    List<String>? languages,
    String? jobMode,
    File? image,
    String? lat,
    String? lng,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      // 🔥 LOG JOB MODE
      print("🚀 [PROVIDER] Updating Profile with jobMode: $jobMode");

      final res = await _apiService.updateProfile(
        token: token,
        name: name,
        phone: phone,
        address: address,
        email: email,
        fathersName: fathersName,
        dob: dob,
        gender: gender,
        whatsapp: whatsapp,
        secondaryPhone: secondaryPhone,
        city: city,
        languages: languages,
        jobMode: jobMode,
        image: image,
        lat: lat,
        lng: lng,
      );
      
      if (res['success'] == true) {
        // 🔥 INTEGRATION: Call the dedicated Job Mode API if requested
        if (jobMode != null) {
          debugPrint("🚀 [PROVIDER] Triggering dedicated Job Mode API: $jobMode");
          await _apiService.updateJobMode(token, jobMode);
          // 🔥 SOCKET SYNC
          SocketService.forceSync(_profile?.vendor.id ?? '');
        }

        // Refresh profile after update
        // 🛡️ Master Sync ensures documents are preserved
        await fetchVendorProfile(token);
        
        // 🔥 CACHE BUSTING: Force the UI to discard the old image
        // 🔥 CACHE BUSTING: Force UI refresh
        if (_profile?.vendor.profilePic != null && _profile!.vendor.profilePic!.isNotEmpty) {
          final p = _profile!.vendor.profilePic!;
          final imageUrl = p.startsWith('http') ? p : '${ApiService.imageBaseUrl}${p.startsWith('/') ? '' : '/'}$p';
          await NetworkImage(imageUrl).evict();
          debugPrint("🧹 CACHE EVICTED: $imageUrl");
        }

        return res;
      } else {
        _error = res['message'] ?? "Failed to update profile";
        return res;
      }
    } catch (e) {
      _error = "Update Exception: $e";
      return {"success": false, "message": e.toString()};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Service Management ---
  List<dynamic> _vendorServices = [];
  List<dynamic> get vendorServices => _vendorServices;

  Future<void> fetchVendorServices() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      if (token.isNotEmpty) {
        final res = await _apiService.getVendorServices(token);
        if (res != null && res['success'] == true) {
          _vendorServices = res['services'] ?? [];
        }
      }
    } catch (e) {
      debugPrint("Fetch Services Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> addVendorService(String sId, String subId, dynamic experienceYears) async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final res = await _apiService.addVendorService(token, sId, subId, experienceYears);
      if (res['success'] == true) {
        await fetchVendorServices();
      }
      return res;
    } catch (e) {
      return {"success": false, "message": e.toString()};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> deleteVendorService(String serviceId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final res = await _apiService.deleteVendorService(token, serviceId);
      if (res['success'] == true) {
        await fetchVendorServices();
      }
      return res;
    } catch (e) {
      return {"success": false, "message": e.toString()};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Helper to set vendor ID after login/registration
  Future<void> setVendorId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vendor_id', id);
  }

  // --- Jobs Fetching ---
  Future<void> fetchJobsForStatus(String tabKey, {bool isLoadMore = false}) async {
    if (tabKey == 'cancelled' && !isLoadMore) {
      await _fetchCancelledJobsMerged();
      return;
    }

    if (tabKey == 'active' && !isLoadMore) {
      await _fetchActiveJobsMerged();
      return;
    }

    if (!isLoadMore) {
      _isLoadingByStatus[tabKey] = true;
      _currentPageByStatus[tabKey] = 1;
      notifyListeners();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      
      if (token.isEmpty) return;

      final res = await _apiService.getVendorBookings(
        token, 
        status: tabKey, 
        page: _currentPageByStatus[tabKey] ?? 1
      );
      
      if (res != null && res['success'] == true) {
        final List? newJobsList = res['data'] ?? res['bookings'] ?? res['jobs'];
        if (newJobsList is List) {
          if (isLoadMore) {
            _jobsByStatus[tabKey]!.addAll(newJobsList);
            _currentPageByStatus[tabKey] = (_currentPageByStatus[tabKey] ?? 1) + 1;
          } else {
            _jobsByStatus[tabKey] = List.from(newJobsList);
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching $tabKey jobs: $e");
    } finally {
      _isLoadingByStatus[tabKey] = false;
      notifyListeners();
    }
  }

  /// Cancelled tab includes vendor-rejected manual jobs (API stores them as `rejected`).
  Future<void> _fetchCancelledJobsMerged() async {
    _isLoadingByStatus['cancelled'] = true;
    _currentPageByStatus['cancelled'] = 1;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      if (token.isEmpty) return;

      final results = await Future.wait([
        _apiService.getVendorBookings(token, status: 'cancelled', page: 1),
        _apiService.getVendorBookings(token, status: 'rejected', page: 1),
      ]);

      final merged = <dynamic>[];
      final seenIds = <String>{};

      for (final res in results) {
        if (res == null || res['success'] != true) continue;
        final list = res['data'] ?? res['bookings'] ?? res['jobs'];
        if (list is! List) continue;
        for (final job in list) {
          if (job is! Map) continue;
          final id = (job['id'] ?? job['booking_id'])?.toString() ?? '';
          if (id.isEmpty || seenIds.contains(id)) continue;
          seenIds.add(id);
          merged.add(job);
        }
      }

      merged.sort((a, b) {
        final aId = (a is Map ? (a['id'] ?? a['booking_id']) : 0);
        final bId = (b is Map ? (b['id'] ?? b['booking_id']) : 0);
        return (bId is num ? bId : int.tryParse('$bId') ?? 0)
            .compareTo(aId is num ? aId : int.tryParse('$aId') ?? 0);
      });

      _jobsByStatus['cancelled'] = merged;
    } catch (e) {
      debugPrint('Error fetching cancelled/rejected jobs: $e');
    } finally {
      _isLoadingByStatus['cancelled'] = false;
      notifyListeners();
    }
  }

  /// In Progress tab — only accepted / started jobs (strict status filter).
  Future<void> _fetchActiveJobsMerged() async {
    _isLoadingByStatus['active'] = true;
    _currentPageByStatus['active'] = 1;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      if (token.isEmpty) return;

      final results = await Future.wait([
        _apiService.getVendorBookings(token, status: 'accepted', page: 1),
        _apiService.getVendorBookings(token, status: 'started', page: 1),
      ]);

      final merged = <dynamic>[];
      final seenIds = <String>{};

      for (final res in results) {
        if (res == null || res['success'] != true) continue;
        final list = res['data'] ?? res['bookings'] ?? res['jobs'];
        if (list is! List) continue;
        for (final job in list) {
          if (job is! Map) continue;
          final jobMap = Map<String, dynamic>.from(job);
          if (!TransactionStatsUtils.isInProgressBooking(jobMap)) continue;
          final id = (jobMap['id'] ?? jobMap['booking_id'])?.toString() ?? '';
          if (id.isEmpty || seenIds.contains(id)) continue;
          seenIds.add(id);
          merged.add(jobMap);
        }
      }

      merged.sort((a, b) {
        final aId = (a is Map ? (a['id'] ?? a['booking_id']) : 0);
        final bId = (b is Map ? (b['id'] ?? b['booking_id']) : 0);
        return (bId is num ? bId : int.tryParse('$bId') ?? 0)
            .compareTo(aId is num ? aId : int.tryParse('$aId') ?? 0);
      });

      _jobsByStatus['active'] = merged;
    } catch (e) {
      debugPrint('Error fetching active/accepted jobs: $e');
    } finally {
      _isLoadingByStatus['active'] = false;
      notifyListeners();
    }
  }

  /// Remove a job from all cached lists immediately (e.g. after completion).
  void removeJobFromAllLists(String bookingId) {
    if (bookingId.isEmpty) return;
    for (final key in _jobsByStatus.keys) {
      _jobsByStatus[key] = _jobsByStatus[key]!
          .where((job) {
            if (job is! Map) return true;
            final id = (job['id'] ?? job['booking_id'])?.toString() ?? '';
            return id != bookingId;
          })
          .toList();
    }
    notifyListeners();
  }

  /// Refresh lists after vendor completes a job (OTP flow or status update).
  Future<void> refreshJobsAfterComplete(String bookingId) async {
    removeJobFromAllLists(bookingId);
    await Future.wait([
      fetchJobsForStatus('active'),
      fetchJobsForStatus('completed'),
      fetchDashboardData(),
      fetchTransactions(),
      fetchEarnings(),
    ]);
  }

  /// Refresh lists after vendor accepts a manual job.
  Future<void> refreshJobsAfterAccept() async {
    await Future.wait([
      fetchJobsForStatus('new'),
      fetchJobsForStatus('active'),
      fetchDashboardData(),
    ]);
  }

  /// Refresh lists after vendor declines a manual job.
  Future<void> refreshJobsAfterReject() async {
    await Future.wait([
      fetchJobsForStatus('new'),
      fetchJobsForStatus('active'),
      fetchJobsForStatus('cancelled'),
      fetchDashboardData(),
    ]);
  }

  Future<void> fetchAllJobs() async {
    await Future.wait([
      fetchJobsForStatus('new'),
      fetchJobsForStatus('active'),
      fetchJobsForStatus('completed'),
      fetchJobsForStatus('cancelled'),
    ]);
  }

  String? _statusError;
  String? get statusError => _statusError;

  // --- In-app notifications ---
  bool _notificationsLoading = false;
  bool get notificationsLoading => _notificationsLoading;

  List<Map<String, dynamic>> _notificationsAll = [];
  List<Map<String, dynamic>> _notificationsJobs = [];
  List<Map<String, dynamic>> _notificationsPayments = [];
  List<Map<String, dynamic>> _notificationsSystem = [];

  List<Map<String, dynamic>> get notificationsAll => List.unmodifiable(_notificationsAll);
  List<Map<String, dynamic>> get notificationsJobs => List.unmodifiable(_notificationsJobs);
  List<Map<String, dynamic>> get notificationsPayments => List.unmodifiable(_notificationsPayments);
  List<Map<String, dynamic>> get notificationsSystem => List.unmodifiable(_notificationsSystem);

  int _totalUnreadNotifications = 0;
  int get totalUnreadNotifications => _totalUnreadNotifications;

  final Map<String, int> _notificationUnreadByCategory = {
    'All': 0,
    'Jobs': 0,
    'Payments': 0,
    'System': 0,
  };

  int notificationUnreadFor(String category) => _notificationUnreadByCategory[category] ?? 0;

  /// Jobs + earnings totals aligned with the Earnings screen (transactions + completed jobs).
  Map<String, num> get unifiedEarningsStats {
    return TransactionStatsUtils.lifetimeAndMonthStats(
      transactions: _transactionsData,
      completedBookings: _jobsByStatus['completed'] ?? [],
    );
  }

  static bool _isNotificationUnread(Map<String, dynamic> item) {
    final read = item['is_read'];
    return read == 0 || read == '0' || read == false;
  }

  static int _countUnread(List<Map<String, dynamic>> items) =>
      items.where(_isNotificationUnread).length;

  static List<Map<String, dynamic>> _parseNotificationList(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> fetchNotifications([String? providedToken]) async {
    _notificationsLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = providedToken ?? prefs.getString('auth_token') ?? '';
      if (token.isEmpty) return;

      final results = await Future.wait([
        _apiService.getVendorNotificationsAll(token),
        _apiService.getVendorNotificationsJobs(token),
        _apiService.getVendorNotificationsPayments(token),
        _apiService.getVendorNotificationsSystem(token),
      ]);

      _notificationsAll = _parseNotificationList(results[0]['data']);
      _notificationsJobs = _parseNotificationList(results[1]['data']);
      _notificationsPayments = _parseNotificationList(results[2]['data']);
      _notificationsSystem = _parseNotificationList(results[3]['data']);

      _notificationUnreadByCategory['All'] = _countUnread(_notificationsAll);
      _notificationUnreadByCategory['Jobs'] = _countUnread(_notificationsJobs);
      _notificationUnreadByCategory['Payments'] = _countUnread(_notificationsPayments);
      _notificationUnreadByCategory['System'] = _countUnread(_notificationsSystem);
      _totalUnreadNotifications = _notificationUnreadByCategory['All']!;
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    } finally {
      _notificationsLoading = false;
      notifyListeners();
    }
  }

  void markAllNotificationsRead() {
    for (final list in [
      _notificationsAll,
      _notificationsJobs,
      _notificationsPayments,
      _notificationsSystem,
    ]) {
      for (final item in list) {
        item['is_read'] = 1;
      }
    }
    _notificationUnreadByCategory.updateAll((_, __) => 0);
    _totalUnreadNotifications = 0;
    notifyListeners();
  }

  Future<Map<String, dynamic>> toggleActiveStatus() async {
    _isLoading = true;
    _statusError = null; // Reset previous errors
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      
      final res = await _apiService.toggleVendorStatus(token);
      
      if (res['success'] == true) {
        // Refresh profile to get the new status correctly synced
        await fetchVendorProfile(token);
        _statusError = null;
      } else {
        _statusError = res['message'] ?? "Toggle failed";
        debugPrint("🛑 [TOGGLE ERROR]: $_statusError");
      }
      return res;
    } catch (e) {
      _statusError = "Toggle Exception: $e";
      return {"success": false, "message": e.toString()};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
