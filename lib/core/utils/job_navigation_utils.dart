import 'package:url_launcher/url_launcher.dart';
import 'package:tapasya_vendor_app/core/utils/job_payload_utils.dart';

class JobNavigationUtils {
  static Future<bool> openMaps(Map<String, dynamic> data) async {
    final lat = JobPayloadUtils.latitude(data);
    final lng = JobPayloadUtils.longitude(data);
    final address = JobPayloadUtils.getField(
      data,
      ['pickup_address', 'address', 'formatted_address', 'address_line1'],
      fallback: '',
    ).toString();

    final Uri url;
    if (lat.isNotEmpty && lng.isNotEmpty) {
      url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    } else if (address.isNotEmpty) {
      url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
      );
    } else {
      return false;
    }

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }
}
