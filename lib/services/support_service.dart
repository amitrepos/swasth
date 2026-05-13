import '../config/app_config.dart';
import 'api_client.dart';

/// Fetches public support contacts (email + WhatsApp) from the backend.
///
/// The endpoint is unauthenticated — used by the web "Contact Us" footer
/// which renders before login. Treat the response as best-effort: if the
/// call fails, the UI should fall back to hiding the section rather than
/// surfacing an error to the visitor.
class SupportContacts {
  final String email;
  final String? whatsappNumber;
  final String? phoneNumber;

  const SupportContacts({
    required this.email,
    this.whatsappNumber,
    this.phoneNumber,
  });
}

class SupportService {
  /// Short timeout for this footer-only call. The endpoint returns 3 small
  /// strings; if the backend can't respond in 8s the visitor is on a bad
  /// network (2G/3G) and we should drop the spinner rather than hang the
  /// dashboard. The widget treats errors as "hide the section."
  static const Duration _timeout = Duration(seconds: 8);

  Future<SupportContacts> fetchContacts() async {
    final url = Uri.parse('${AppConfig.serverHost}/api/public/support');
    final data = await ApiClient.sendJsonObject(
      () => ApiClient.httpClient.get(url, headers: ApiClient.headers()),
      timeout: _timeout,
    );
    final email = (data['email'] as String?) ?? 'support@swasth.health';
    final wa = data['whatsapp_number'] as String?;
    final phone = data['phone_number'] as String?;
    return SupportContacts(
      email: email,
      whatsappNumber: (wa != null && wa.trim().isNotEmpty) ? wa.trim() : null,
      phoneNumber: (phone != null && phone.trim().isNotEmpty)
          ? phone.trim()
          : null,
    );
  }
}
