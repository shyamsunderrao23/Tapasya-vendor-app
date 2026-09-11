import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tapasya_vendor_app/core/navigation/session_service.dart';

class ApiService {
  static const String _baseUrl = 'https://tapasyaserver.sreerasthusilvers.co.in/api';
  static const String imageBaseUrl = 'https://tapasyaserver.sreerasthusilvers.co.in';
  final _storage = const FlutterSecureStorage();

  void _checkUnauthorized(int statusCode) {
    if (statusCode == 401) {
      SessionService.handleSessionExpired();
    }
  }

  Future<http.Response> _authGet(Uri url, {String? token, String contentType = 'application/json'}) async {
    final response = await http.get(
      url,
      headers: await _getHeaders(token: token, contentType: contentType),
    );
    _checkUnauthorized(response.statusCode);
    return response;
  }

  Future<http.Response> _authPost(
    Uri url, {
    String? token,
    Object? body,
    String contentType = 'application/json',
  }) async {
    final response = await http.post(
      url,
      headers: await _getHeaders(token: token, contentType: contentType),
      body: body,
    );
    _checkUnauthorized(response.statusCode);
    return response;
  }

  Future<http.Response> _authPut(
    Uri url, {
    String? token,
    Object? body,
    String contentType = 'application/json',
  }) async {
    final response = await http.put(
      url,
      headers: await _getHeaders(token: token, contentType: contentType),
      body: body,
    );
    _checkUnauthorized(response.statusCode);
    return response;
  }

  Future<http.Response> _authDelete(Uri url, {String? token, String contentType = 'application/json'}) async {
    final response = await http.delete(
      url,
      headers: await _getHeaders(token: token, contentType: contentType),
    );
    _checkUnauthorized(response.statusCode);
    return response;
  }

  /// Helper to get common headers with optional Bearer token
  Future<Map<String, String>> _getHeaders({
    String? token, 
    String contentType = 'application/json',
    bool isFirebaseToken = false,
  }) async {
    final effectiveToken = token ?? await _storage.read(key: 'token');
    final headers = {
      'Accept': 'application/json',
    };

    if (effectiveToken != null && effectiveToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $effectiveToken';
      if (isFirebaseToken) {
        debugPrint("🔑 [API AUTH] Using FIREBASE Token (Bearer ...${effectiveToken.substring(effectiveToken.length - 10)})");
      } else {
        debugPrint("🔑 [API AUTH] Using BACKEND Token (Bearer ...${effectiveToken.substring(effectiveToken.length - 10)})");
      }
    }

    if (contentType.isNotEmpty) {
      headers['Content-Type'] = contentType;
    }

    return headers;
  }

  /// Fetches bank details based on IFSC code using Razorpay IFSC API
  Future<Map<String, dynamic>?> getBankDetails(String ifsc) async {
    final url = Uri.parse('https://ifsc.razorpay.com/$ifsc');
    try {
      debugPrint("🔍 [API SERVICE] Looking up IFSC: $ifsc");
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint("✅ [API SERVICE] IFSC Found: ${data['BANK']} - ${data['BRANCH']}");
        return data;
      } else {
        debugPrint("⚠️ [API SERVICE] IFSC Not Found (Status: ${response.statusCode})");
        return null;
      }
    } catch (e) {
      debugPrint("❌ [API SERVICE] IFSC Lookup Error: $e");
      return null;
    }
  }

  /// Verifies the vendor's PAN card by uploading an image.
  /// Returns the parsed response data if successful.
  Future<Map<String, dynamic>?> verifyPan(String token, File panImage, String vendorId) async {
    final url = Uri.parse('$_baseUrl/vendor/pan/verify');
    
    try {
      print("📤 [PAN VERIFY SUBMIT] URL: $url");
      print("📤 [PAN VERIFY SUBMIT] VendorID: $vendorId");

      var request = http.MultipartRequest('POST', url);
      
      request.headers.addAll(await _getHeaders(token: token, contentType: ''));

      request.fields['vendor_id'] = vendorId;
      
      String fileName = panImage.path.split('/').last;
      String extension = fileName.split('.').last.toLowerCase();
      MediaType mediaType = MediaType('image', extension == 'png' ? 'png' : 'jpeg');

      final int imageSizeInKB = panImage.lengthSync() ~/ 1024;
      debugPrint("🚀 [PAN VERIFY] File: $fileName, Size: ${imageSizeInKB}KB, MediaType: $mediaType");

      request.files.add(
        await http.MultipartFile.fromPath(
          'panImage',
          panImage.path,
          contentType: mediaType,
          filename: fileName,
        ),
      );

      http.StreamedResponse response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      print("📥 [PAN VERIFY RESPONSE] Status: ${response.statusCode}");
      print("📥 [PAN VERIFY RESPONSE] Body: $responseBody");

      if (response.statusCode == 200) {
        return json.decode(responseBody);
      } else {
        print('PAN Verification failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ [PAN VERIFY ERROR] $e');
      return null;
    }
  }

  /// Uploads and verifies Aadhar details
  Future<Map<String, dynamic>?> uploadAadhar(String token, File frontImage, File backImage, String vendorId) async {
    final url = Uri.parse('$_baseUrl/vendor/aadhar/verify');
    
    try {
      var request = http.MultipartRequest('POST', url);
      
      request.headers.addAll(await _getHeaders(token: token, contentType: ''));

      request.fields['vendor_id'] = vendorId;
      
      final int fSize = frontImage.lengthSync() ~/ 1024;
      final int bSize = backImage.lengthSync() ~/ 1024;
      debugPrint("🚀 [AADHAR VERIFY] Front: ${fSize}KB, Back: ${bSize}KB");

      request.files.add(await http.MultipartFile.fromPath('front', frontImage.path));
      request.files.add(await http.MultipartFile.fromPath('back', backImage.path));

      print("📤 [AADHAR VERIFY SUBMIT] URL: $url");
      print("📤 [AADHAR VERIFY SUBMIT] VendorID: $vendorId");

      var response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      print("📥 [AADHAR VERIFY RESPONSE] Status: ${response.statusCode}");
      print("📥 [AADHAR VERIFY RESPONSE] Body: $responseBody");

      if (response.statusCode == 200) {
        return json.decode(responseBody);
      } else {
        return null;
      }
    } catch (e) {
      print('❌ [AADHAR VERIFY ERROR] $e');
      return null;
    }
  }

  /// Updates bank details on the backend
  Future<Map<String, dynamic>?> updateBankDetails(String token, String bankName, String accountNumber, String ifscCode, String holderName, String vendorId) async {
    final url = Uri.parse('$_baseUrl/vendor/bank/verify');
    
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(token: token),
        body: json.encode({
          'vendor_id': vendorId,
          'account_number': accountNumber,
          'ifsc_code': ifscCode,
          'account_holder_name': holderName,
          'bank_name': bankName,
        }),
      );

      print("📤 [BANK DETAILS SUBMIT] URL: $url");
      print("📤 [BANK DETAILS SUBMIT] Data: $bankName, $accountNumber, $holderName, $vendorId");

      print("📥 [BANK DETAILS RESPONSE] Status: ${response.statusCode}");
      print("📥 [BANK DETAILS RESPONSE] Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      print('❌ [BANK DETAILS ERROR] $e');
      return null;
    }
  }

  /// Verifies bank details directly via backend (Cashfree)
  Future<Map<String, dynamic>?> verifyBank(
    String token,
    String vendorId,
    String accountNumber,
    String ifscCode,
    String holderName,
    String bankName,
  ) async {
    final url = Uri.parse('$_baseUrl/vendor/bank/verify');

    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(token: token),
        body: jsonEncode({
          "vendor_id": vendorId,
          "account_number": accountNumber,
          "ifsc_code": ifscCode,
          "account_holder_name": holderName,
          "bank_name": bankName
        }),
      );

      print("📥 RESPONSE: ${response.body}");

      return jsonDecode(response.body);
    } catch (e) {
      print("❌ ERROR: $e");
      return null;
    }
  }

  /// Fetches the saved bank details for a specific vendor.
  /// Endpoint: GET /vendor/bank/{vendor_id}
  Future<Map<String, dynamic>?> getVendorBankDetails(String token, String vendorId) async {
    final url = Uri.parse('$_baseUrl/vendor/bank/$vendorId');
    try {
      final response = await _authGet(url, token: token, contentType: '');
      print("📥 [GET BANK DETAILS] Status: ${response.statusCode} | Body: ${response.body}");
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ [GET BANK DETAILS ERROR] $e');
      return null;
    }
  }


  /// Matches the captured selfie against the system's records.
Future<Map<String, dynamic>?> faceMatch(
  File selfieImage,
  File documentImage,
  String vendorId, {
  String? token,
}) async {
  final url = Uri.parse('$_baseUrl/vendors/face-match');

  try {
    var request = http.MultipartRequest('POST', url);
    request.headers.addAll(await _getHeaders(token: token, contentType: ''));

    request.fields['vendor_id'] = vendorId;

    request.files.add(
      await http.MultipartFile.fromPath(
        'selfie_image',
        selfieImage.path,
      ),
    );

    request.files.add(
      await http.MultipartFile.fromPath(
        'document_image', // ✅ match backend
        documentImage.path,
      ),
    );

    var response = await request.send();

    final body = await response.stream.bytesToString();

    print("FACE STATUS: ${response.statusCode}");
    print("FACE BODY: $body");

    if (response.statusCode == 200) {
      return json.decode(body);
    } else {
      return null;
    }
  } catch (e) {
    print("❌ [FACE MATCH ERROR] $e");
    return null;
  }
}

  /// Fetches all available services.
  Future<List<dynamic>> getServices() async {
    final url = Uri.parse('$_baseUrl/admin/services');
    try {
      final response = await http.get(url, headers: {'Accept': 'application/json'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['services'] ?? [];
      }
      return [];
    } catch (e) {
      print('❌ [GET SERVICES ERROR] $e');
      return [];
    }
  }

  /// Fetches sub-services for a specific service ID.
  Future<List<dynamic>> getSubServices(String serviceId) async {
    final url = Uri.parse('$_baseUrl/admin/service/$serviceId/sub-services');
    try {
      final response = await http.get(url, headers: {'Accept': 'application/json'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['sub_services'] ?? [];
      }
      return [];
    } catch (e) {
      print('❌ [GET SUB-SERVICES ERROR] $e');
      return [];
    }
  }

/// Final registration call for the vendor.
/// Now requires idToken (Firebase ID Token) to pass authorization.

Future<Map<String, dynamic>?> registerVendor({
  required String token,
  required String fullName,
  required String fatherName,
  required String dob, // dd-MM-yyyy -> will convert to yyyy-MM-dd
  required String gender,
  required int age,
  required String email,
  required String whatsappNumber,
  required String secondaryPhone,
  required String city,
  required String address,
  required double lat,
  required double lng,
  required String jobMode,
  required List<String> languages,
  required List<Map<String, dynamic>> services,
  required File profilePic,
  String aadharNo = '',
  String panNo = '',
}) async {
  final url = Uri.parse('$_baseUrl/vendors/register');

  try {
    if (!profilePic.existsSync()) {
      return {
        "success": false,
        "message": "Profile picture missing. Please re-upload."
      };
    }

    var request = http.MultipartRequest('POST', url);

    request.headers.addAll(await _getHeaders(token: token, contentType: '', isFirebaseToken: true));

    print("📤 [REGISTRATION SUBMIT] URL: $url");
    print("📤 [REGISTRATION SUBMIT] Token: ${token.substring(0, 10)}...");

    // Format DOB to yyyy-MM-dd
    String formattedDob = dob;
    try {
      List<String> parts = dob.split('-');
      if (parts.length == 3) {
        formattedDob = "${parts[2]}-${parts[1]}-${parts[0]}";
      }
    } catch (_) {}

    // TEXT FIELDS
    request.fields['full_name'] = fullName;
    request.fields['father_name'] = fatherName;
    request.fields['dob'] = formattedDob;
    request.fields['gender'] = gender.toLowerCase().trim();
    request.fields['age'] = age.toString();
    request.fields['email'] = email;
    request.fields['whatsapp_number'] = whatsappNumber;
    request.fields['secondary_phone'] = secondaryPhone;
    request.fields['city'] = city;
    request.fields['address'] = address;
    request.fields['lat'] = lat.toString();
    request.fields['lng'] = lng.toString();
    request.fields['job_mode'] = jobMode;
    request.fields['aadhar_no'] = aadharNo;
    request.fields['pan_no'] = panNo;
    
    // JSON STRINGS
    request.fields['languages'] = json.encode(languages);
    request.fields['services'] = json.encode(services);

    // FILES
    request.files.add(
      await http.MultipartFile.fromPath(
        'profile_pic',
        profilePic.path,
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    var response = await request.send();
    final body = await response.stream.bytesToString();

    print("REGISTER STATUS: ${response.statusCode}");
    print("REGISTER BODY: $body");

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(body);
    } else {
      Map<String, dynamic> errorData = {};
      try {
        errorData = json.decode(body);
      } catch (_) {}
      return {
        "success": false,
        "message": errorData['message'] ?? body
      };
    }
  } catch (e) {
    print("REGISTER ERROR: $e");
    return {
      "success": false,
      "message": "Exception: $e"
    };
  }
}


Future<Map<String, dynamic>?> getMyVendor(String token) async {
  final url = Uri.parse('$_baseUrl/vendors/me');

  try {
    // 🔥 DEBUG TOKEN
    print("🔥 FINAL TOKEN USED: $token");

    var response = await _authGet(url, token: token, contentType: '');

    print("📥 [GET MY VENDOR RESPONSE] Status: ${response.statusCode}");
    
    // 🔥 PRETTY PRINT FULL JSON
    try {
      final dynamic decoded = json.decode(response.body);
      final String prettyJson = const JsonEncoder.withIndent('  ').convert(decoded);
      debugPrint("📂 [GET MY VENDOR FULL JSON]:\n$prettyJson");
    } catch (e) {
      print("📥 [GET MY VENDOR RESPONSE] Raw Body: ${response.body}");
    }

    if (response.statusCode == 200 || response.statusCode == 403) {
      return json.decode(response.body);
    }

    if (response.statusCode == 401) {
      return null;
    }

    return null;
  } catch (e) {
    print('❌ [GET MY VENDOR ERROR] $e');
    return null;
  }
}

  /// Fetches vendor details by phone number.
  Future<Map<String, dynamic>?> getVendorByPhone(String phone) async {
    final url = Uri.parse('$_baseUrl/vendors/phone/$phone');
    try {
      final response = await http.get(url, headers: await _getHeaders(token: '', contentType: ''));

      print("📥 [GET VENDOR BY PHONE RESPONSE] Status: ${response.statusCode}");
      print("📥 [GET VENDOR BY PHONE RESPONSE] Body: ${response.body}");

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      print('❌ [GET VENDOR BY PHONE ERROR] $e');
      return null;
    }
  }

  /// Logs in a returning vendor using their Firebase ID Token
  Future<Map<String, dynamic>?> loginVendor(String idToken) async {
    final url = Uri.parse('$_baseUrl/vendors/login');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(token: idToken, contentType: '', isFirebaseToken: true),
      );

      print("📥 [LOGIN RESPONSE] Status: ${response.statusCode}");
      print("📥 [LOGIN RESPONSE] Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 403) {
        // Return body even for 403 (Vendor not approved yet) so OtpScreen can route them to Dashboard
        return json.decode(response.body);
      } else {
        return null; // Not registered or unauthorized
      }
    } catch (e) {
      print('Error logging in vendor: $e');
      return null;
    }
  }

  /// Toggles the vendor's active status (online/offline)
  Future<Map<String, dynamic>> toggleVendorStatus(String token) async {
    final url = Uri.parse('$_baseUrl/vendors/toggle-status');

    try {
      final response = await _authPut(url, token: token, contentType: '');
      
      print("📤 [TOGGLE STATUS SUBMIT] URL: $url");
      print("📥 [TOGGLE STATUS RESPONSE] Status: ${response.statusCode}");
      print("📥 [TOGGLE STATUS RESPONSE] Body: ${response.body}");

      final body = json.decode(response.body);
      return body;
    } catch (e) {
      print('Error toggling vendor status: $e');
      return {"success": false, "message": "Exception: $e"};
    }
  }

  /// Saves the FCM token to the backend
  Future<void> saveFcmToken(String jwtToken, String fcmToken) async {
    final url = Uri.parse('$_baseUrl/vendors/save-fcm-token');

    try {
      final response = await _authPost(
        url,
        token: jwtToken,
        body: jsonEncode({
          "fcm_token": fcmToken
        }),
      );
      
      print("📤 [SAVE FCM SUBMIT] URL: $url");
      print("📥 [SAVE FCM RESPONSE] Status: ${response.statusCode}");
      print("📥 [SAVE FCM RESPONSE] Body: ${response.body}");
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  /// Updates the vendor's job mode (auto/manual)f

  /// Accepts a job booking
  Future<Map<String, dynamic>> acceptBooking(String token, String bookingId, [String vendorId = '']) async {
    return bookingAction(token, bookingId, vendorId, "ACCEPTED");
  }

  Future<Map<String, dynamic>?> getBookingDetails(String token, String bookingId) async {
    final url = Uri.parse('$_baseUrl/admin/bookings/$bookingId');
    try {
      print("GET BOOKING DETAILS URL: $url");
      print("GET BOOKING DETAILS HEADERS: {'Accept': 'application/json', 'Authorization': 'Bearer $token'}");
      
      final response = await _authGet(url, token: token, contentType: '').timeout(const Duration(seconds: 15));
      
      print("GET BOOKING DETAILS STATUS: ${response.statusCode}");
      print("GET BOOKING DETAILS BODY: ${response.body}");
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching booking details: $e');
      return null;
    }
  }

  // Alias for getBookingDetails as requested by user
  Future<Map<String, dynamic>?> getSingleBooking(String token, String bookingId) async {
    return getBookingDetails(token, bookingId);
  }

  /// Fetches lists of bookings for a vendor
  Future<Map<String, dynamic>?> getVendorBookings(String token, {String? status, int? page, int? limit}) async {
    List<String> queryParams = [];
    if (status != null) queryParams.add('status=$status');
    if (page != null) queryParams.add('page=$page');
    if (limit != null) queryParams.add('limit=$limit');
    
    String queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    final url = Uri.parse('$_baseUrl/vendors/bookings$queryString');
    
    try {
      final response = await _authGet(url, token: token, contentType: '');
      
      print("GET VENDOR BOOKINGS (${status ?? 'ALL'}, page: ${page ?? 1}): ${response.statusCode}");
      print("GET VENDOR BOOKINGS BODY: ${response.body}");

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching vendor bookings: $e');
      return null;
    }
  }

  /// Sends an OTP to the customer for job completion verification
  Future<Map<String, dynamic>> sendCompletionOtp(String token, String bookingId) async {
    final url = Uri.parse('$_baseUrl/vendors/bookings/$bookingId/send-completion-otp');
    try {
      final response = await _authPost(url, token: token);
      print("📤 [SEND OTP SUBMIT] URL: $url");
      print("📥 [SEND OTP RESPONSE] Status: ${response.statusCode} | Body: ${response.body}");
      return jsonDecode(response.body);
    } catch (e) {
      return {"success": false, "message": "Exception: $e"};
    }
  }

  /// Verifies the customer OTP to complete the job
  Future<Map<String, dynamic>> verifyCompletionOtp(String token, String bookingId, String otp) async {
    final url = Uri.parse('$_baseUrl/vendors/bookings/$bookingId/verify-otp');
    try {
      final response = await _authPost(
        url,
        token: token,
        body: jsonEncode({
          "booking_id": bookingId,
          "otp": otp
        }),
      );
      print("📤 [VERIFY OTP SUBMIT] URL: $url | OTP: $otp");
      print("📥 [VERIFY OTP RESPONSE] Status: ${response.statusCode} | Body: ${response.body}");
      return jsonDecode(response.body);
    } catch (e) {
      return {"success": false, "message": "Exception: $e"};
    }
  }

  /// Fetches contact info from the admin for vendors
  Future<Map<String, dynamic>> getContactInfo() async {
    final url = Uri.parse('$_baseUrl/admin/contact/vendor');
    try {
      final response = await http.get(url, headers: await _getHeaders(contentType: ''));
      print("📥 [GET CONTACT INFO RESPONSE] Status: ${response.statusCode} | Body: ${response.body}");
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {"success": false, "message": "API Error: ${response.statusCode}"};
    } catch (e) {
      return {"success": false, "message": "Exception: $e"};
    }
  }

  /// Updates status of a booking (ACCEPTED, STARTED, COMPLETED, REJECTED)
  Future<Map<String, dynamic>> bookingAction(String token, String bookingId, String vendorId, String action) async {
    final url = Uri.parse('$_baseUrl/vendors/bookings/action');
    final reqBodyMap = {
      "booking_id": bookingId,
      "action": action,
    };
    final reqBodyJson = jsonEncode(reqBodyMap);

    print("==================================================");
    print("📡 [BOOKING ACTION REQUEST]");
    print("   • Booking ID: $bookingId");
    print("   • Action: $action");
    print("   • API URL: $url");
    print("   • Request Body: $reqBodyJson");
    print("==================================================");

    try {
      final response = await _authPost(
        url,
        token: token,
        body: reqBodyJson,
      );
      
      print("==================================================");
      print("📥 [BOOKING ACTION RESPONSE]");
      print("   • Booking ID: $bookingId");
      print("   • API URL: $url");
      print("   • HTTP Status: ${response.statusCode}");
      print("   • Response Body: ${response.body}");
      print("==================================================");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        try {
          final errData = jsonDecode(response.body);
          if (errData is Map<String, dynamic>) {
            return errData;
          }
        } catch (_) {}
        return {"success": false, "message": "API Error: ${response.statusCode} - ${response.body}"};
      }
    } catch (e) {
      print("❌ [BOOKING ACTION EXCEPTION] $e");
      return {"success": false, "message": "Network Exception: $e"};
    }
  }

  /// Convenience for Rejecting a booking
  Future<Map<String, dynamic>> rejectBooking(String token, String bookingId, String vendorId) async {
    return bookingAction(token, bookingId, vendorId, "REJECTED");
  }

  /// Fetches vendor dashboard stats and featured jobs
  Future<Map<String, dynamic>> getDashboard(String token) async {
    final url = Uri.parse('$_baseUrl/vendors/dashboard');
    try {
      final response = await _authGet(url, token: token, contentType: '');
      print("DASHBOARD RESPONSE STATUS: ${response.statusCode}");
      print("DASHBOARD BODY: ${response.body}");
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {"success": false, "message": "Error ${response.statusCode}"};
      }
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  /// Fetches the full profile data including business stats
  Future<Map<String, dynamic>> getProfileFull(String token) async {
    final url = Uri.parse('$_baseUrl/vendors/profile-full');
    try {
      final response = await _authGet(url, token: token, contentType: '');
      print("PROFILE FULL STATUS: ${response.statusCode}");
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {"success": false, "message": "API Error: ${response.statusCode}"};
    } catch (e) {
      return {"success": false, "message": "Exception: $e"};
    }
  }

  /// Fetches earnings data for graphing
  Future<Map<String, dynamic>> getEarnings(String token, String type) async {
    final url = Uri.parse('$_baseUrl/vendors/earnings?type=$type');
    try {
      final response = await _authGet(url, token: token, contentType: '');
      print("EARNINGS ($type) STATUS: ${response.statusCode}");
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {"success": false, "message": "API Error: ${response.statusCode}"};
    } catch (e) {
      return {"success": false, "message": "Exception: $e"};
    }
  }

  /// Fetches main earnings data dynamically
  Future<Map<String, dynamic>> getMainEarnings(String token) async {
    final url = Uri.parse('$_baseUrl/vendors/main-earnings');
    try {
      final response = await _authGet(url, token: token, contentType: '');
      print("MAIN EARNINGS STATUS: ${response.statusCode}");
      print("🔥 MAIN EARNINGS BODY: ${response.body}");
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {"success": false, "message": "API Error: ${response.statusCode}"};
    } catch (e) {
      return {"success": false, "message": "Exception: $e"};
    }
  }

  /// Fetches recent financial transactions
  Future<Map<String, dynamic>> getTransactions(String token) async {
    final url = Uri.parse('$_baseUrl/vendors/transactions');
    try {
      final response = await _authGet(url, token: token, contentType: '');
      print("TRANSACTIONS STATUS: ${response.statusCode}");
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {"success": false, "message": "API Error: ${response.statusCode}"};
    } catch (e) {
      return {"success": false, "message": "Exception: $e"};
    }
  }

  /// Fetches vendor performance metrics
  Future<Map<String, dynamic>> getPerformance(String token) async {
    final url = Uri.parse('$_baseUrl/vendors/performance');
    try {
      final response = await _authGet(url, token: token, contentType: '');
      print("PERFORMANCE STATUS: ${response.statusCode}");
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {"success": false, "message": "API Error: ${response.statusCode}"};
    } catch (e) {
      return {"success": false, "message": "Exception: $e"};
    }
  }

  Future<Map<String, dynamic>> getJobs(String token, String type) async {
    final url = Uri.parse('$_baseUrl/vendors/jobs?type=$type');
    try {
      final response = await _authGet(url, token: token, contentType: '').timeout(const Duration(seconds: 15));
      
      print("JOBS ($type) STATUS: ${response.statusCode}");
      print("JOBS ($type) BODY: ${response.body}");
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {"success": false, "message": "API Error: ${response.statusCode}"};
    } catch (e) {
      return {"success": false, "message": "Exception: $e"};
    }
  }

  /// Fetches vendor availability schedule
  Future<Map<String, dynamic>> getAvailability(String token) async {
    final url = Uri.parse('$_baseUrl/vendors/availability');
    try {
      final response = await _authGet(url, token: token, contentType: '');
      print("GET AVAILABILITY STATUS: ${response.statusCode}");
      print("🔥 API DATA: ${response.body}");
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {"success": false, "message": "API Error: ${response.statusCode}"};
    } catch (e) {
      return {"success": false, "message": "Exception: $e"};
    }
  }

  /// Updates vendor availability schedule
  Future<Map<String, dynamic>> setAvailability(String token, List availability) async {
    final url = Uri.parse('$_baseUrl/vendors/set-availability');

     print("🔥 DATA SENT:");
  print(availability);
    try {
      final response = await _authPost(
        url,
        token: token,
        body: jsonEncode({"availability": availability}),
      );

      print("📤 [SET AVAILABILITY SUBMIT] URL: $url");
      print("📤 [SET AVAILABILITY SUBMIT] Count: ${availability.length} days");
      
      print("📥 [SET AVAILABILITY RESPONSE] Status: ${response.statusCode}");
      print("📥 [SET AVAILABILITY RESPONSE] Body: ${response.body}");

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {"success": false, "message": "API Error: ${response.statusCode}"};
    } catch (e) {
      return {"success": false, "message": "Exception: $e"};
    }
  }

  /// Fetches vendor reviews with filtering and pagination
  Future<Map<String, dynamic>> getReviewsFull(String token, {int? rating, int page = 1, int limit = 10}) async {
    String urlStr = '$_baseUrl/vendors/reviews-full?page=$page&limit=$limit';
    if (rating != null) urlStr += '&rating=$rating';
    final url = Uri.parse(urlStr);
    try {
      final response = await _authGet(url, token: token, contentType: '');
      print("REVIEWS FULL STATUS: ${response.statusCode}");
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {"success": false, "message": "API Error: ${response.statusCode}"};
    } catch (e) {
      return {"success": false, "message": "Exception: $e"};
    }
  }

  /// Updates the vendor's live location
  Future<void> updateLocation(String token, double lat, double lng) async {
    final url = Uri.parse('$_baseUrl/vendors/location/update');
    try {
      await _authPost(
        url,
        token: token,
        body: jsonEncode({
          "lat": lat.toString(),
          "lng": lng.toString()
        }),
      );
    } catch (e) {
      print("Location error: $e");
    }
  }

  /// Updates vendor profile (Multipart)
  Future<Map<String, dynamic>> updateProfile({
    required String token,
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
    final url = Uri.parse('$_baseUrl/vendors/profile');

    try {
      var request = http.MultipartRequest('PUT', url);
      request.headers.addAll(await _getHeaders(token: token, contentType: ''));

      request.fields['name'] = name;
      request.fields['phone'] = phone;
      request.fields['address'] = address;
      request.fields['email'] = email;
      
      if (fathersName != null) request.fields['fathers_name'] = fathersName;
      if (dob != null) request.fields['dob'] = dob;
      if (gender != null) request.fields['gender'] = gender;
      if (whatsapp != null) request.fields['whatsapp_number'] = whatsapp;
      if (secondaryPhone != null) request.fields['secondary_mobile_number'] = secondaryPhone;
      if (city != null) request.fields['city'] = city;
      if (languages != null) request.fields['languages'] = json.encode(languages);
      if (jobMode != null) {
        request.fields['job_mode'] = jobMode.toLowerCase().trim();
        print("📝 [API] Setting job_mode to: ${request.fields['job_mode']}");
      }
      
      if (lat != null) request.fields['lat'] = lat;
      if (lng != null) request.fields['lng'] = lng;

      if (image != null) {
        request.files.add(
          await http.MultipartFile.fromPath('profile_pic', image.path)
        );
      }

      var response = await http.Response.fromStream(await request.send());
      _checkUnauthorized(response.statusCode);
      print("📡 [UPDATE PROFILE] STATUS: ${response.statusCode}");
      print("📥 [UPDATE PROFILE] RESPONSE: ${response.body}");
      return jsonDecode(response.body);

    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  /// Updates the vendor's job mode (auto/manual)
  Future<Map<String, dynamic>> updateJobMode(String token, String mode) async {
    final url = Uri.parse('$_baseUrl/vendors/job-mode');

    try {
      final response = await _authPut(
        url,
        token: token,
        body: jsonEncode({"job_mode": mode.toLowerCase().trim()}),
      );

      print("📤 [JOB MODE SUBMIT] URL: $url");
      print("📤 [JOB MODE SUBMIT] Mode: $mode");
      print("📥 [JOB MODE RESPONSE] Status: ${response.statusCode}");
      print("📥 [JOB MODE RESPONSE] Body: ${response.body}");
      
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ [JOB MODE ERROR] $e');
      return {"success": false, "message": e.toString()};
    }
  }

  /// Service Management APIs
  Future<Map<String, dynamic>?> getVendorServices(String token) async {
    final url = Uri.parse('$_baseUrl/vendors/services');
    try {
      final response = await _authGet(url, token: token, contentType: '');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching vendor services: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> addVendorService(String token, String serviceId, String subServiceId, dynamic experienceYears) async {
    final url = Uri.parse('$_baseUrl/vendors/add-service');
    try {
      final response = await _authPost(
        url,
        token: token,
        body: jsonEncode({
          "service_id": serviceId,
          "sub_service_id": subServiceId,
          "experience_years": experienceYears
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        return {"success": false, "message": "Error ${response.statusCode}: ${response.body}"};
      }
    } catch (e) {
      return {"success": false, "message": "Exception: $e"};
    }
  }

  Future<Map<String, dynamic>> deleteVendorService(String token, String serviceId) async {
    final url = Uri.parse('$_baseUrl/vendors/service/$serviceId');
    try {
      final response = await _authDelete(url, token: token, contentType: '');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {"success": false, "message": "Error ${response.statusCode}: ${response.body}"};
      }
    } catch (e) {
      return {"success": false, "message": "Exception: $e"};
    }
  }

  /// Submits a support request for a vendor
  Future<Map<String, dynamic>> submitSupportRequest({
    required String vendorName,
    required String mobileNumber,
    required String issueType,
    required String message,
    required bool needContact,
  }) async {
    final url = Uri.parse('$_baseUrl/vendors/support');
    try {
      final response = await _authPost(
        url,
        body: jsonEncode({
          "vendor_name": vendorName,
          "mobile_number": mobileNumber,
          "issue_type": issueType,
          "message": message,
          "need_contact": needContact
        }),
      );
      
      return jsonDecode(response.body);
    } catch (e) {
      return {"success": false, "message": "Exception: $e"};
    }
  }

  Future<Map<String, dynamic>> _getVendorNotifications(String token, String path) async {
    final url = Uri.parse('$_baseUrl/vendor/notifications/$path');
    try {
      final response = await _authGet(url, token: token, contentType: '');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {"success": false, "message": "Error ${response.statusCode}"};
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  Future<Map<String, dynamic>> getVendorNotificationsAll(String token) =>
      _getVendorNotifications(token, 'all');

  Future<Map<String, dynamic>> getVendorNotificationsJobs(String token) =>
      _getVendorNotifications(token, 'jobs');

  Future<Map<String, dynamic>> getVendorNotificationsPayments(String token) =>
      _getVendorNotifications(token, 'payments');

  Future<Map<String, dynamic>> getVendorNotificationsSystem(String token) =>
      _getVendorNotifications(token, 'system');
}
