import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tapasya_vendor_app/core/widgets/app_toast.dart';

class ShareAppHelper {
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.tapasya.vendor';

  static String getShareMessage({String? vendorName, String? referralCode}) {
    final nameStr = (vendorName != null && vendorName.trim().isNotEmpty)
        ? "$vendorName invites you to join Tapasya Partner!\n\n"
        : "";

    return "🚀 *Join Tapasya Partner Network!*\n\n"
        "${nameStr}Are you a skilled technician or service expert? Join Tapasya to get instant job requests, guaranteed weekly payouts, and total control of your business schedule!\n\n"
        "✨ *Key Benefits:*\n"
        "• 📈 Steady flow of genuine verified customer jobs\n"
        "• 💰 Secure & fast payouts directly to your bank\n"
        "• ⚡ Auto & Manual job acceptance flexibility\n"
        "• ⭐ Transparent ratings & performance rewards\n\n"
        "📲 *Download the Tapasya Partner App now:*\n"
        "$playStoreUrl\n\n"
        "Start growing your service business today! 💼🔧";
  }

  /// Directly triggers native system share sheet (Image 2) with the app icon image included
  static Future<void> shareApp({
    String? vendorName,
    String? referralCode,
    Rect? sharePositionOrigin,
  }) async {
    try {
      HapticFeedback.mediumImpact();
      final text = getShareMessage(
        vendorName: vendorName,
        referralCode: referralCode,
      );

      // Extract app icon from assets to temp file so native share preview includes the app icon
      try {
        final byteData = await rootBundle.load('assets/images/tapasya_logo.png');
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/tapasya_logo.png');
        await file.writeAsBytes(
          byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        );

        if (await file.exists()) {
          await Share.shareXFiles(
            [XFile(file.path)],
            text: text,
            subject: 'Join Tapasya Partner Network',
            sharePositionOrigin: sharePositionOrigin,
          );
          return;
        }
      } catch (e) {
        debugPrint("⚠️ Asset image load failed for share, falling back to text: $e");
      }

      // Fallback to text-only native share if image extraction fails
      await Share.share(
        text,
        subject: 'Join Tapasya Partner Network',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      debugPrint("❌ ShareApp Error: $e");
    }
  }

  /// Directly invokes native mobile share sheet (bypasses custom UI, opens Image 2 directly)
  static void showShareModal(BuildContext context, {String? vendorName, String? referralCode}) {
    shareApp(vendorName: vendorName, referralCode: referralCode);
  }

  /// Copy link to clipboard with haptic feedback & toast
  static Future<void> copyAppLink(BuildContext context, {String? referralCode}) async {
    try {
      HapticFeedback.lightImpact();
      await Clipboard.setData(const ClipboardData(text: playStoreUrl));
      if (context.mounted) {
        AppToast.show(context, "App download link copied to clipboard!");
      }
    } catch (e) {
      debugPrint("❌ Copy Link Error: $e");
    }
  }

  /// Share directly to WhatsApp if installed, with native share fallback
  static Future<void> shareViaWhatsApp({
    String? vendorName,
    String? referralCode,
  }) async {
    try {
      HapticFeedback.lightImpact();
      final message = Uri.encodeComponent(
        getShareMessage(vendorName: vendorName, referralCode: referralCode),
      );
      final whatsappUrl = Uri.parse("whatsapp://send?text=$message");
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        await shareApp(vendorName: vendorName, referralCode: referralCode);
      }
    } catch (e) {
      debugPrint("❌ WhatsApp Share Error: $e");
      await shareApp(vendorName: vendorName, referralCode: referralCode);
    }
  }

  /// Share directly via SMS
  static Future<void> shareViaSMS({
    String? vendorName,
    String? referralCode,
  }) async {
    try {
      HapticFeedback.lightImpact();
      final message = Uri.encodeComponent(
        getShareMessage(vendorName: vendorName, referralCode: referralCode),
      );
      final smsUrl = Uri.parse("sms:?body=$message");
      if (await canLaunchUrl(smsUrl)) {
        await launchUrl(smsUrl, mode: LaunchMode.externalApplication);
      } else {
        await shareApp(vendorName: vendorName, referralCode: referralCode);
      }
    } catch (e) {
      debugPrint("❌ SMS Share Error: $e");
      await shareApp(vendorName: vendorName, referralCode: referralCode);
    }
  }
}
