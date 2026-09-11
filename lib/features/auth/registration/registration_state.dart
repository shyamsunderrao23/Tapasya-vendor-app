import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tapasya_vendor_app/core/utils/notification_helper.dart';
import 'package:tapasya_vendor_app/services/api_service.dart';

class SelectedService {
  final String serviceId;
  final String serviceName;
  final String subServiceId;
  final String subServiceName;
  final String experienceYears;

  SelectedService({
    required this.serviceId,
    required this.serviceName,
    required this.subServiceId,
    required this.subServiceName,
    required this.experienceYears,
  });

Map<String, dynamic> toMap() {
  return {
    'service_id': serviceId,
    'sub_service_id': subServiceId,
    'experience_years': int.tryParse(experienceYears) ?? 0,
  };
}

  factory SelectedService.fromMap(Map<String, dynamic> map) {
    return SelectedService(
      serviceId: map['service_id']?.toString() ?? '',
      serviceName: map['service_name']?.toString() ?? '',
      subServiceId: map['sub_service_id']?.toString() ?? '',
      subServiceName: map['sub_service_name']?.toString() ?? '',
      experienceYears: map['experience_years']?.toString() ?? '',
    );
  }
}

class RegistrationState extends ChangeNotifier {
  final _secureStorage = const FlutterSecureStorage();
  
  // Step 1: Personal Details
  String name = ''; 
  String fathersName = '';
  String dob = '';
  String email = '';
  String gender = 'Male';
  String age = '';
  String whatsappNumber = '';
  String secondaryMobileNumber = '';
  String city = '';
  String address = '';
  List<String> languages = [];
  String referralCode = '';
  XFile? profilePic;
  String lat = '';
  String lng = '';
  String jobMode = 'manual'; // Strictly manual mode for V1
  bool hasCompletedAvailability = false;
  // Step 3: Identity Verification (Reordered)
  XFile? aadharFrontImage;
  XFile? aadharBackImage;
  String aadharNumber = '';
  String aadharStatus = 'pending'; // pending, submitted, approved, rejected
  
  XFile? panImage;
  String panNumber = '';
  String panStatus = 'pending'; // pending, submitted, approved, rejected

  // Step 4: Face Verification (New)
  XFile? selfieImage;
  String faceStatus = 'pending'; // pending, submitted, approved, rejected

  // Step 6: Bank Verification (New)
  String bankName = '';
  String accountNumber = '';
  String ifscCode = '';
  String accountHolderName = '';
  String bankStatus = 'pending'; // pending, submitted, approved, rejected
  
  // Step 2: Service Selection (Now Multiple)
  List<SelectedService> selectedServices = [];
  
  // Current selection state (for dropdowns)
  String? currentServiceId;
  String? currentServiceName;
  String? currentSubServiceId;
  String? currentSubServiceName;
  String currentExperience = '';

  // Meta Recovery / Navigation Flags
  bool hasSeenOnboarding = false;
  bool hasCompletedRegistration = false;

  String phoneNumber = '';
  String authToken = ''; // Field for login auth token
  String vendorId = ''; // Backend UUID
  
  // OCR / Verification extracted data
  String aadharExtractedName = ''; 
  String? registrationError; // For displaying errors across screens

  void updatePersonalDetails({
    required String name,
    required String fathersName,
    required String dob,
    required String email,
    required String gender,
    required String whatsappNumber,
    required String secondaryMobileNumber,
    required String city,
    required String address,
    required List<String> languages,
    String referralCode = '',
    required String lat,
    required String lng,
  }) {
    this.name = name;
    this.fathersName = fathersName;
    this.dob = dob;
    this.email = email;
    this.gender = gender;
    this.whatsappNumber = whatsappNumber;
    this.secondaryMobileNumber = secondaryMobileNumber;
    this.city = city;
    this.address = address;
    this.languages = languages;
    this.referralCode = referralCode;
    this.lat = lat;
    this.lng = lng;
    
    print("🔄 [STATE UPDATE] Personal Details: Name=$name, Email=$email, City=$city");
    saveToLocal();
    notifyListeners();
  }

  void setHasSeenOnboarding(bool value) {
    hasSeenOnboarding = value;
    saveToLocal();
    notifyListeners();
  }

  void completeRegistration() {
    hasCompletedRegistration = true;
    debugPrint("✅ [REGISTRATION] FINISHED! All steps verified.");
    saveToLocal();
    notifyListeners();
  }

  Future<void> clearAllData() async {
    debugPrint("🗑️ [STATE] CLEARING ALL LOCAL DATA...");
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _secureStorage.deleteAll();
    
    // Reset in-memory strings
    name = ''; fathersName = ''; dob = ''; email = ''; gender = 'Male';
    age = ''; whatsappNumber = ''; secondaryMobileNumber = '';
    city = ''; address = ''; languages = []; referralCode = '';
    jobMode = ''; hasCompletedAvailability = false;
    aadharNumber = ''; aadharStatus = 'pending';
    panNumber = ''; panStatus = 'pending';
    faceStatus = 'pending'; bankStatus = 'pending';
    phoneNumber = ''; authToken = ''; vendorId = '';
    hasSeenOnboarding = false;
    hasCompletedRegistration = false;
    
    notifyListeners();
  }

  void completeAvailability() {
    hasCompletedAvailability = true;
    saveToLocal();
    notifyListeners();
  }

  void updateAadhar({XFile? frontImage, XFile? backImage, String? number, String? status}) {
    if (frontImage != null) aadharFrontImage = frontImage;
    if (backImage != null) aadharBackImage = backImage;
    if (number != null) aadharNumber = number;
    if (status != null) aadharStatus = status;
    else aadharStatus = 'submitted';
    
    saveToLocal();
    notifyListeners();
  }

  void updatePan({XFile? image, String? number, String? status}) {
    if (image != null) panImage = image;
    if (number != null) panNumber = number;
    if (status != null) panStatus = status;
    else panStatus = 'submitted';
    
    saveToLocal();
    notifyListeners();
  }

  void updateBankDetails({
    required String bankName,
    required String accountNumber,
    required String ifscCode,
    required String accountHolderName,
    String? status,
  }) {
    this.bankName = bankName;
    this.accountNumber = accountNumber;
    this.ifscCode = ifscCode;
    this.accountHolderName = accountHolderName;
    if (status != null) bankStatus = status;
    else bankStatus = 'submitted';
    
    saveToLocal();
    notifyListeners();
  }

  void setCurrentService({String? id, String? name}) {
    currentServiceId = id;
    currentServiceName = name;
    // Clear sub-service when service changes
    currentSubServiceId = null;
    currentSubServiceName = null;
    currentExperience = '';
    notifyListeners();
  }

  void setCurrentSubService({String? id, String? name}) {
    currentSubServiceId = id;
    currentSubServiceName = name;
    notifyListeners();
  }

  void setCurrentExperience(String years) {
    currentExperience = years;
    notifyListeners();
  }

  void addSelectedService() {
    if (currentServiceId != null && currentSubServiceId != null) {
      selectedServices.add(SelectedService(
        serviceId: currentServiceId!,
        serviceName: currentServiceName!,
        subServiceId: currentSubServiceId!,
        subServiceName: currentSubServiceName!,
        experienceYears: currentExperience,
      ));
      
      // Clear current selection after adding
      currentServiceId = null;
      currentServiceName = null;
      currentSubServiceId = null;
      currentSubServiceName = null;
      currentExperience = '';
      saveToLocal();
      notifyListeners();
    }
  }

  void removeSelectedService(int index) {
    if (index >= 0 && index < selectedServices.length) {
      selectedServices.removeAt(index);
      saveToLocal();
      notifyListeners();
    }
  }

  void updateSelfie(XFile? image) {
    selfieImage = image;
    saveToLocal();
    notifyListeners();
  }

  Future<void> updateRegistrationToken(String token) async {
    authToken = token;
    debugPrint("🔐 [STATE] Writing token to Secure Storage & Prefs...");
    await _secureStorage.write(key: 'token', value: token);
    
    // 🔥 SYNC for VendorProvider
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    
    saveToLocal();
    notifyListeners();
  }

  void updatePhone(String number) {
    phoneNumber = number;
    debugPrint("🚀 [REGISTRATION] Phone Updated: $number");
    saveToLocal();
    notifyListeners();
  }

  void updateProfilePic(XFile image) {
    profilePic = image;
    saveToLocal();
    notifyListeners();
  }

  void updateBankStatus(String status) {
    bankStatus = status;
    saveToLocal();
    notifyListeners();
  }

  void updateFaceStatus(String status) {
    faceStatus = status;
    saveToLocal();
    notifyListeners();
  }

  void updateVendorId(String id) {
    vendorId = id;
    saveToLocal();
    notifyListeners();
  }

  void updateAadharExtractedName(String name) {
    aadharExtractedName = name;
    saveToLocal();
    notifyListeners();
  }

  void setRegistrationError(String? error) {
    registrationError = error;
    notifyListeners();
  }

  // --- Persistence Logic ---

  Future<void> saveToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'has_seen_onboarding': hasSeenOnboarding,
      'has_completed_registration': hasCompletedRegistration,
      'name': name,
      'fathers_name': fathersName,
      'dob': dob,
      'email': email,
      'gender': gender,
      'age': age,
      'whatsapp_number': whatsappNumber,
      'secondary_mobile_number': secondaryMobileNumber,
      'city': city,
      'address': address,
      'languages': languages, // JSON encode will handle this list
      'referral_code': referralCode,
      'lat': lat,
      'lng': lng,
      'job_mode': jobMode,
      'has_completed_availability': hasCompletedAvailability,
      'profile_pic_path': profilePic?.path,
      'aadhar_number': aadharNumber,
      'aadhar_front_path': aadharFrontImage?.path,
      'aadhar_back_path': aadharBackImage?.path,
      'aadhar_status': aadharStatus,
      'pan_number': panNumber,
      'pan_image_path': panImage?.path,
      'pan_status': panStatus,
      'selfie_image_path': selfieImage?.path,
      'face_status': faceStatus,
      'bank_name': bankName,
      'account_number': accountNumber,
      'ifsc_code': ifscCode,
      'account_holder_name': accountHolderName,
      'bank_status': bankStatus,
      'selected_services': selectedServices.map((s) => s.toMap()).toList(),
      'phone_number': phoneNumber,
      'registration_token': authToken,
      'vendor_id': vendorId,
      'aadhar_extracted_name': aadharExtractedName,
    };

    debugPrint("💾 [REGISTRATION] Saving state to SharedPreferences...");
    debugPrint("💾 [REGISTRATION] Data Snapshot: {name: $name, services: ${selectedServices.length}, step: ${getNextStepPath()}}");
    
    // Save core session data separately for robustness
    await prefs.setString('auth_phone', phoneNumber);
    await prefs.setString('auth_vendor_id', vendorId);
    await prefs.setString('auth_token', authToken); // 🔥 SYNC for VendorProvider
    await prefs.setBool('has_seen_onboarding', hasSeenOnboarding);
    await prefs.setBool('has_completed_registration', hasCompletedRegistration);
    
    await prefs.setString('vendor_onboarding', json.encode(data));
  }

  Future<void> loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Load Session Data (Independent of the big blob)
    authToken = await _secureStorage.read(key: 'token') ?? '';
    phoneNumber = prefs.getString('auth_phone') ?? '';
    vendorId = prefs.getString('auth_vendor_id') ?? '';
    hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
    hasCompletedRegistration = prefs.getBool('has_completed_registration') ?? false;
    
    debugPrint("🔐 [STATE] Session Loaded: token=${authToken.isNotEmpty}, phone=$phoneNumber, vendorId=$vendorId");
    
    // 🔥 SYNC for VendorProvider (ensure it survives app restarts)
    if (authToken.isNotEmpty) {
      await prefs.setString('auth_token', authToken);
    }

    final String? jsonStr = prefs.getString('vendor_onboarding');
    if (jsonStr != null) {
      print("💾 [LOCAL LOADED] vendor_onboarding data found.");
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      
      // Merge with session data if blob exists
      hasSeenOnboarding = data['has_seen_onboarding'] ?? hasSeenOnboarding;
      hasCompletedRegistration = data['has_completed_registration'] ?? hasCompletedRegistration;
      name = data['name'] ?? '';
      fathersName = data['fathers_name'] ?? '';
      dob = data['dob'] ?? '';
      email = data['email'] ?? '';
      gender = data['gender'] ?? 'Male';
      age = data['age'] ?? '';
      whatsappNumber = data['whatsapp_number'] ?? '';
      secondaryMobileNumber = data['secondary_mobile_number'] ?? '';
      city = data['city'] ?? '';
      address = data['address'] ?? '';
      languages = List<String>.from(data['languages'] ?? []);
      referralCode = data['referral_code'] ?? '';
      lat = data['lat'] ?? '';
      lng = data['lng'] ?? '';
      jobMode = data['job_mode'] ?? '';
      hasCompletedAvailability = data['has_completed_availability'] ?? false;
      if (data['profile_pic_path'] != null) profilePic = XFile(data['profile_pic_path']);
      
      aadharNumber = data['aadhar_number'] ?? '';
      if (data['aadhar_front_path'] != null) aadharFrontImage = XFile(data['aadhar_front_path']);
      else if (data['aadhar_image_path'] != null) aadharFrontImage = XFile(data['aadhar_image_path']); // Migration
      if (data['aadhar_back_path'] != null) aadharBackImage = XFile(data['aadhar_back_path']);
      aadharStatus = data['aadhar_status'] ?? 'pending';

      panNumber = data['pan_number'] ?? '';
      if (data['pan_image_path'] != null) panImage = XFile(data['pan_image_path']);
      panStatus = data['pan_status'] ?? 'pending';

      bankName = data['bank_name'] ?? '';
      accountNumber = data['account_number'] ?? '';
      ifscCode = data['ifsc_code'] ?? '';
      accountHolderName = data['account_holder_name'] ?? '';
      bankStatus = data['bank_status'] ?? 'pending';

      if (data['selfie_image_path'] != null) selfieImage = XFile(data['selfie_image_path']);
      faceStatus = data['face_status'] ?? 'pending';
      
      if (data['selected_services'] != null) {
        selectedServices = (data['selected_services'] as List)
            .map((s) => SelectedService.fromMap(s as Map<String, dynamic>))
            .toList();
      }
      if (phoneNumber.isEmpty) phoneNumber = data['phone_number'] ?? '';
      if (vendorId.isEmpty) vendorId = data['vendor_id'] ?? '';

      debugPrint("📥 [REGISTRATION] Loaded from Local: status=$hasCompletedRegistration, name=$name");
      debugPrint("📥 [REGISTRATION] Resuming at Step: ${getNextStepPath()}");
      
      // --- CRITICAL SANITY CHECK ---
      if (hasCompletedRegistration) {
        if (panStatus != 'approved' || aadharStatus != 'approved' || bankStatus != 'approved' || faceStatus != 'approved') {
          debugPrint("🚨 [SANITY CHECK] Force resetting completion flag - documents pending approval.");
          hasCompletedRegistration = false;
        }
      }
      notifyListeners();
    } else {
      debugPrint("📥 [REGISTRATION] No local session found. Starting fresh.");
    }
  }

  /// Wipes all local registration data for a "Fresh Start"
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('vendor_onboarding');
    await prefs.remove('auth_phone');
    await prefs.remove('auth_vendor_id');
    await prefs.remove('has_seen_onboarding');
    await prefs.remove('has_completed_registration');
    await _secureStorage.delete(key: 'token'); 
    
    // Reset all local variables
    name = ''; fathersName = ''; dob = ''; email = ''; gender = 'Male';
    age = ''; whatsappNumber = ''; secondaryMobileNumber = '';
    city = ''; address = ''; languages = []; referralCode = '';
    lat = ''; lng = ''; jobMode = ''; hasCompletedAvailability = false;
    aadharFrontImage = null; aadharBackImage = null; aadharNumber = ''; aadharStatus = 'pending';
    panImage = null; panNumber = ''; panStatus = 'pending';
    selfieImage = null;
    bankName = ''; accountNumber = ''; ifscCode = ''; accountHolderName = ''; bankStatus = 'pending';
    faceStatus = 'pending';
    selectedServices = [];
    hasSeenOnboarding = false;
    hasCompletedRegistration = false;
    phoneNumber = '';
    authToken = '';
    vendorId = '';
    
    notifyListeners();
    debugPrint("🧹 [STATE] Application data reset to defaults via clearAll().");
  }

  Future<void> clearLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('vendor_onboarding');
    _resetState();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('vendor_onboarding');
    await prefs.remove('auth_phone');
    await prefs.remove('auth_vendor_id');
    await prefs.remove('auth_token');
    // We keep 'has_seen_onboarding' so users don't see intro again on same device
    await prefs.remove('has_completed_registration');
    await _secureStorage.delete(key: 'token');

    authToken = '';
    phoneNumber = '';
    vendorId = '';
    name = '';
    fathersName = '';

    debugPrint("🚪 [STATE] User logged out. Session cleared, onboarding flag preserved.");
    await NotificationHelper.onLogout();
    notifyListeners();
  }

  void _resetState() {
    hasSeenOnboarding = false;
    hasCompletedRegistration = false;
    hasCompletedAvailability = false;
    name = '';
    fathersName = '';
    dob = '';
    email = '';
    gender = 'Male';
    age = '';
    whatsappNumber = '';
    secondaryMobileNumber = '';
    city = '';
    address = '';
    languages = [];
    referralCode = '';
    lat = '';
    lng = '';
    jobMode = 'manual';
    profilePic = null;
    aadharNumber = '';
    panNumber = '';
    panImage = null;
    selfieImage = null;
    bankName = '';
    accountNumber = '';
    ifscCode = '';
    accountHolderName = '';
    bankStatus = 'pending';
    faceStatus = 'pending';
    aadharFrontImage = null;
    aadharBackImage = null;
    aadharStatus = 'pending';
    panStatus = 'pending';
    selectedServices = [];
    phoneNumber = '';
    authToken = '';
    vendorId = '';
    saveToLocal();
    notifyListeners();
  }

  Future<bool> syncWithBackend() async {
    if (authToken.isEmpty) return false;
    
    final apiService = ApiService();
    debugPrint("🔄 [STATE SYNC] Calling getMyVendor...");
    
    try {
      final response = await apiService.getMyVendor(authToken);
      if (response != null) {
        updateFromBackend(response);
        return true;
      }
    } catch (e) {
      debugPrint("❌ [STATE SYNC ERROR] $e");
    }
    return false;
  }

  String getNextStepPath() {
    debugPrint("🛣️ [ROUTING] Calculating next registration step...");
    debugPrint("🛣️ [ROUTING] State: vendorId=$vendorId, token=${authToken.isNotEmpty}");
    
    // 🔥 PRIORITY 1: Authenticated users should ALWAYS land in the app, not steps
    if (authToken.isNotEmpty) {
      // If we have a token but haven't finished syncing full data, 
      // we still treat them as an existing user to avoid kicking them to Step 1.
      debugPrint("🛣️ [ROUTING] Returning Vendor Detected. Path: /home");
      return '/home';
    }

    // Stage 1: Auth (Must have phone AND token)
    if (phoneNumber.isEmpty || authToken.isEmpty) {
      debugPrint("🛣️ [ROUTING] Status: NO AUTH. Path: /register/verify");
      return '/register/verify';
    }

    // Stage 2: Basic Profile (Only for brand new registration)
    if (name.isEmpty) {
      debugPrint("🛣️ [ROUTING] Status: STEP 1 PENDING. Path: /register/step1");
      return '/register/step1';
    }
    if (selectedServices.isEmpty) {
      debugPrint("🛣️ [ROUTING] Status: STEP 2 PENDING. Path: /register/step2");
      return '/register/step2';
    }
    
    debugPrint("🛣️ [ROUTING] Fallback. Path: /home");
    return '/home';
  }

  bool get isRegistrationInProgress => phoneNumber.isNotEmpty && !hasCompletedRegistration;

  int calculateAge() {
    if (dob.isEmpty) return 0;
    try {
      // dob is in dd-MM-yyyy format
      List<String> parts = dob.split('-');
      if (parts.length != 3) return 0;
      DateTime birthDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      DateTime today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return 0;
    }
  }

  void updateJobMode(String mode) {
    jobMode = mode;
    saveToLocal();
    notifyListeners();
  }

  /// Synchronizes local state with backend vendor profile data
  void updateFromBackend(Map<String, dynamic> vendorData) {
    // 🚀 NEW NESTING LOGIC
    // The backend returns { "data": { "vendor": {...}, "services": [...] } }
    final data = vendorData['data'] ?? vendorData;
    final Map<String, dynamic> vendor = data['vendor'] ?? data;
    final List<dynamic> servicesList = data['services'] ?? [];

    debugPrint("🔄 [STATE SYNC] Parsing backend data. HasVendor: ${data['vendor'] != null}, Services: ${servicesList.length}");

    final bName = vendor['full_name'] ?? vendor['name'] ?? '';
    if (bName.isNotEmpty) name = bName;

    final bFather = vendor['father_name'] ?? vendor['fatherName'] ?? '';
    if (bFather.isNotEmpty) fathersName = bFather;

    final bDob = vendor['dob'] ?? '';
    if (bDob.isNotEmpty) dob = bDob;

    final bEmail = vendor['email'] ?? '';
    if (bEmail.isNotEmpty) email = bEmail;

    final bGender = vendor['gender'] ?? 'Male';
    if (bGender.isNotEmpty && bGender != 'Male') gender = bGender;

    final bAge = (vendor['age'] ?? 0);
    if (bAge > 0) age = bAge.toString();

    final bWhatsapp = vendor['whatsapp_number'] ?? vendor['whatsappNumber'] ?? '';
    if (bWhatsapp.isNotEmpty) whatsappNumber = bWhatsapp;

    final bSecondary = vendor['secondary_phone'] ?? vendor['secondaryPhone'] ?? '';
    if (bSecondary.isNotEmpty) secondaryMobileNumber = bSecondary;

    final bCity = vendor['city'] ?? '';
    if (bCity.isNotEmpty) city = bCity;

    final bAddress = vendor['address'] ?? '';
    if (bAddress.isNotEmpty) address = bAddress;
    
    if (vendor['languages'] != null) {
      languages = List<String>.from(vendor['languages']);
    }
    
    final bLat = (vendor['lat'] ?? '').toString();
    if (bLat.isNotEmpty) lat = bLat;

    final bLng = (vendor['lng'] ?? '').toString();
    if (bLng.isNotEmpty) lng = bLng;

    final bJobMode = vendor['jobMode'] ?? '';
    if (bJobMode.isNotEmpty) jobMode = bJobMode;
    
    // Document Statuses (Enhanced with new document_status key support)
    final docStatus = vendor['document_status'];
    if (docStatus != null && docStatus is Map) {
      // 🚀 NEW LOGIC: Use the dedicated 'document_status' object
      final ad = docStatus['aadhaar'];
      if (ad != null && ad is Map) aadharStatus = ad['status']?.toString().toLowerCase() ?? 'pending';
      
      final pn = docStatus['pan'];
      if (pn != null && pn is Map) panStatus = pn['status']?.toString().toLowerCase() ?? 'pending';
    } else {
      // 🕰️ BACKWARD COMPATIBILITY
      aadharStatus = vendor['aadharStatus'] ?? 'pending';
      panStatus = vendor['panStatus'] ?? 'pending';
      bankStatus = vendor['bankStatus'] ?? 'pending';
      faceStatus = vendor['faceStatus'] ?? 'pending';
    }
    
    // Other Flags
    vendorId = vendor['id']?.toString() ?? vendor['_id']?.toString() ?? '';
    
    // Service Completion Logic (Using the servicesList from new nesting)
    if (servicesList.isNotEmpty) {
      selectedServices = servicesList.map((s) {
        return SelectedService(
          serviceId: s['service_id']?.toString() ?? '',
          serviceName: s['service_name']?.toString() ?? '',
          subServiceId: s['sub_service_id']?.toString() ?? '',
          subServiceName: s['sub_service_name']?.toString() ?? '',
          experienceYears: s['experience_years']?.toString() ?? '0',
        );
      }).toList();
    }

    // Availability
    hasCompletedAvailability = vendor['availability'] != null;

    // Final Completion Logic
    // If the backend says active or approved, or if all major steps are done
    final String status = vendor['status'] ?? '';
    if (status == 'active' || status == 'approved' || 
        (aadharStatus == 'approved' && panStatus == 'approved' && bankStatus == 'approved' && faceStatus == 'approved')) {
      hasCompletedRegistration = true;
    }
    
    // 🔥 STICKY COMPLETION: If we previously finished registration locally, 
    // don't let a 'pending' backend status kick us back to the steps.
    if (!hasCompletedRegistration) {
      // Check if we have at least submitted everything (have a Vendor ID)
      if (vendorId.isNotEmpty && aadharStatus != 'pending' && panStatus != 'pending') {
          debugPrint("📝 [STATE] Marking as completed based on existing Vendor ID.");
          hasCompletedRegistration = true;
      }
    }

    // Onboarding is definitely seen if they have a profile/ID
    hasSeenOnboarding = true;

    saveToLocal();
    notifyListeners();
    debugPrint("✅ [STATE SYNC] Sync complete. hasCompletedRegistration: $hasCompletedRegistration, vendorId: $vendorId");
  }
}
