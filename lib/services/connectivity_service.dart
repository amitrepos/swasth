import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._();
  factory ConnectivityService() => _instance;
  ConnectivityService._();

  /// Returns true if the backend server is reachable (2s timeout).
  Future<bool> isServerReachable() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.serverHost}/health'),
      ).timeout(const Duration(seconds: 2));
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }
}
