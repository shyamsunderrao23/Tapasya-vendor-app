import 'dart:convert';

class VendorProfile {
  final Vendor vendor;
  final List<VendorDocument> documents;
  final List<VendorService> services;

  VendorProfile({
    required this.vendor,
    required this.documents,
    required this.services,
  });

  factory VendorProfile.fromMap(Map<String, dynamic> map, {List<VendorDocument>? existingDocuments}) {
    final vendorData = map['vendor'] ?? map;
    final List<VendorDocument> docs = [];

    // 🔥 PATH SCRAPER: Check all common backend paths!
    dynamic raw;
    if (map['documents'] is Map || map['documents'] is List) {
      raw = map['documents'];
    } else if (vendorData['documents'] is Map || vendorData['documents'] is List) {
      raw = vendorData['documents'];
    } else if (map['data'] != null && map['data']['documents'] != null) {
      raw = map['data']['documents'];
    } else if (map['data'] != null && map['data']['vendor'] != null && map['data']['vendor']['documents'] != null) {
      raw = map['data']['vendor']['documents'];
    }

    if (raw != null && raw is Map) {
      final docMap = raw as Map<String, dynamic>;
      docMap.forEach((key, val) {
        if (val is Map) {
          final type = (val['type']?.toString() ?? key).toUpperCase().trim();
          final status = (val['status']?.toString() ?? 'PENDING').toUpperCase().trim();
          docs.add(VendorDocument(
            documentType: type,
            documentNumber: "", 
            verificationStatus: status,
          ));
        }
      });
      print("🎯 [SCRAPER] Found ${docs.length} documents via explicit paths.");
    }
    else if (raw != null && raw is List) {
      docs.addAll((raw as List).map((d) => VendorDocument.fromMap(d)).toList());
    }

    // 🛡️ RECURSIVE FALLBACK: Only if the explicit paths above failed
    if (docs.isEmpty) {
      void findRec(dynamic item) {
        if (raw != null) return;
        if (item is Map) {
          if (item.containsKey('aadhaar') || item.containsKey('documents')) {
            raw = item.containsKey('documents') ? item['documents'] : item;
            return;
          }
          item.values.forEach(findRec);
        } else if (item is List) {
          item.forEach(findRec);
        }
      }
      findRec(map);
      // Process recursive results if found...
      if (raw != null && raw is Map && docs.isEmpty) {
         (raw as Map<String, dynamic>).forEach((k, v) {
            if (v is Map) {
              docs.add(VendorDocument(
                documentType: (v['type']?.toString() ?? k).toUpperCase().trim(),
                documentNumber: "",
                verificationStatus: (v['status']?.toString() ?? 'PENDING').toUpperCase().trim(),
              ));
            }
         });
         print("🚀 [SCRAPER_RECURSIVE] Recovered ${docs.length} documents!");
      }
    }

    // 🏗️ FLAT FIELD HARVESTER: Look for direct 'aadhar'/'pan' strings on the vendor object!
    final possibleAadhar = vendorData['aadhar'] ?? vendorData['aadhaar'] ?? vendorData['aadhar_status'];
    final possiblePan = vendorData['pan'] ?? vendorData['pan_status'];
    
    if (possibleAadhar != null && possibleAadhar is String) {
      if (!docs.any((d) => d.documentType.contains('ADHAAR') || d.documentType.contains('AADHAR'))) {
        docs.add(VendorDocument(documentType: 'AADHAR', documentNumber: '', verificationStatus: possibleAadhar.toUpperCase()));
        print("🏗️ [HARVESTER] Harvested AADHAR status from flat field: $possibleAadhar");
      }
    }
    if (possiblePan != null && possiblePan is String) {
      if (!docs.any((d) => d.documentType == 'PAN')) {
        docs.add(VendorDocument(documentType: 'PAN', documentNumber: '', verificationStatus: possiblePan.toUpperCase()));
        print("🏗️ [HARVESTER] Harvested PAN status from flat field: $possiblePan");
      }
    }

    // 3. 🛡️ PERSISTENCE ENGINE: If no documents in this map, preserve existing ones
    if (docs.isEmpty && existingDocuments != null) {
      docs.addAll(existingDocuments);
    }

    // 🔥 PATH SCRAPER for Services:
    dynamic rawServices = map['services'] ?? vendorData['services'];
    if (rawServices == null && map['data'] != null) {
       rawServices = map['data']['services'] ?? (map['data']['vendor'] != null ? map['data']['vendor']['services'] : null);
    }

    return VendorProfile(
      vendor: Vendor.fromMap(vendorData),
      documents: docs,
      services: (rawServices as List? ?? [])
          .map((s) => VendorService.fromMap(s))
          .toList(),
    );
  }

  factory VendorProfile.fromJson(String source) =>
      VendorProfile.fromMap(json.decode(source));
}

class Vendor {
  final String id;
  final String fullName;
  final String? fathersName;
  final String? dob;
  final String gender;
  final int age;
  final String email;
  final String phone;
  final String? whatsappNumber;
  final String? secondaryMobileNumber;
  final String? city;
  final List<String> languages;
  final String? profilePic;
  final double? lat;
  final double? lng;
  final int activeStatus;
  final String jobMode;
  final String? address;

  Vendor({
    required this.id,
    required this.fullName,
    this.fathersName,
    this.dob,
    required this.gender,
    required this.age,
    required this.email,
    required this.phone,
    this.whatsappNumber,
    this.secondaryMobileNumber,
    this.city,
    this.languages = const [],
    this.profilePic,
    this.lat,
    this.lng,
    required this.activeStatus,
    required this.jobMode,
    this.address,
  });

  factory Vendor.fromMap(Map<String, dynamic> map) {
    // Handling list of languages which might be string or list
    List<String> langs = [];
    if (map['languages'] != null) {
      dynamic raw = map['languages'];
      
      // Helper to handle nested/encoded strings
      List<String> processItem(dynamic item) {
        if (item == null) return [];
        if (item is List) {
          return item.expand((e) => processItem(e)).toList();
        }
        if (item is String) {
          // If it looks like a JSON array/object string, try to decode it
          String trimmed = item.trim();
          if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
            try {
              final decoded = json.decode(trimmed);
              return processItem(decoded);
            } catch (_) {
              // Fall through to manual cleanup if decode fails
            }
          }
          // Clean up and handle comma-separated values
          String cleaned = item.replaceAll('\"', '').replaceAll('[', '').replaceAll(']', '').replaceAll('\\', '').replaceAll('*', '');
          if (cleaned.contains(',')) {
            return cleaned.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          }
          return [cleaned.trim()];
        }
        String cleanedValue = item.toString().replaceAll('\"', '').replaceAll('[', '').replaceAll(']', '').replaceAll('\\', '').replaceAll('*', '');
        if (cleanedValue.contains(',')) {
          return cleanedValue.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        }
        return [cleanedValue.trim()];
      }

      langs = processItem(raw).where((s) => s.isNotEmpty).toSet().toList();
    }

    return Vendor(
      id: map['id'] ?? '',
      fullName: map['full_name'] ?? '',
      fathersName: map['fathers_name'],
      dob: map['dob'],
      gender: map['gender'] ?? '',
      age: map['age'] ?? 0,
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      whatsappNumber: map['whatsapp_number'],
      secondaryMobileNumber: map['secondary_mobile_number'],
      city: map['city'],
      languages: langs,
      profilePic: map['profile_pic'],
      lat: double.tryParse(map['lat']?.toString() ?? ''),
      lng: double.tryParse(map['lng']?.toString() ?? ''),
      activeStatus: map['active_status'] ?? 0,
      jobMode: map['job_mode'] ?? 'manual',
      address: map['address'],
    );
  }
}

class VendorDocument {
  final String documentType;
  final String documentNumber;
  final String? documentFile;
  final String verificationStatus;

  VendorDocument({
    required this.documentType,
    required this.documentNumber,
    this.documentFile,
    required this.verificationStatus,
  });

  factory VendorDocument.fromMap(Map<String, dynamic> map) {
    final type = (map['type']?.toString() ?? map['document_type']?.toString() ?? 'DOCUMENT').toUpperCase().trim();
    final status = (map['status']?.toString() ?? map['verification_status']?.toString() ?? 'PENDING').toUpperCase().trim();
    
    return VendorDocument(
      documentType: type,
      documentNumber: (map['document_number'] ?? map['number'] ?? "").toString(),
      documentFile: map['document_file'] ?? map['file'],
      verificationStatus: status,
    );
  }
}

class VendorService {
  final String serviceId;       // ✅ FIXED (was int ❌)
  final String subServiceId;    // ✅ FIXED
  final double price;           // ✅ FIXED
  final int experienceYears;
  final String serviceName;
  final String subServiceName;

  VendorService({
    required this.serviceId,
    required this.subServiceId,
    required this.price,
    required this.experienceYears,
    required this.serviceName,
    required this.subServiceName,
  });

  factory VendorService.fromMap(Map<String, dynamic> map) {
    return VendorService(
      serviceId: map['service_id'] ?? '',
      subServiceId: map['sub_service_id'] ?? '',

      // ✅ SAFE PARSING
      price: double.tryParse(map['price']?.toString() ?? '0') ?? 0.0,

      experienceYears: map['experience_years'] ?? 0,
      serviceName: map['service_name'] ?? '',
      subServiceName: map['sub_service_name'] ?? '',
    );
  }
}