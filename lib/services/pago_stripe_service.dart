import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:taller_movil/core/config/app_config.dart';
import 'package:taller_movil/services/auth_service.dart';
import 'package:taller_movil/services/api_helper.dart';

class PagoStripeService {
  static final _base = '${AppConfig.baseUrl}/api/pagos';
  final _auth = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// CU40 – Crea el PaymentIntent en Stripe y devuelve el client_secret.
  Future<Map<String, dynamic>> crearIntent(int cotizacionId) async {
    final res = await safePost(
      Uri.parse('$_base/stripe/intent'),
      headers: await _headers(),
      body: jsonEncode({'cotizacion_id': cotizacionId}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 401 || res.statusCode == 403) throw TokenExpiradoException();
    throw Exception(_extraerError(res.body, res.statusCode));
  }

  /// CU40 – Confirma con el backend que Stripe procesó el pago exitosamente.
  Future<Map<String, dynamic>> confirmarPago(
    int cotizacionId,
    String paymentIntentId,
  ) async {
    final res = await safePost(
      Uri.parse('$_base/stripe/confirmar'),
      headers: await _headers(),
      body: jsonEncode({
        'cotizacion_id': cotizacionId,
        'payment_intent_id': paymentIntentId,
      }),
    );
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 401 || res.statusCode == 403) throw TokenExpiradoException();
    throw Exception(_extraerError(res.body, res.statusCode));
  }

  String _extraerError(String body, int statusCode) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['detail']?.toString() ?? 'Error $statusCode';
    } catch (_) {
      // El servidor devolvió HTML u otro formato no JSON
      return 'Error $statusCode del servidor';
    }
  }
}
