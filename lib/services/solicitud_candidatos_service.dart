import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:taller_movil/core/config/app_config.dart';
import 'package:taller_movil/services/api_helper.dart';
import 'package:taller_movil/services/auth_service.dart';

class SolicitudCandidatosService {
  final _auth = AuthService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, dynamic>>> listar(int incidenteId) async {
    final res = await safeGet(
      Uri.parse('${AppConfig.baseUrl}/api/solicitudes/$incidenteId/talleres-candidatos'),
      headers: await _authHeaders(),
    );
    verificarRespuesta(res);
    final data = jsonDecode(res.body) as List;
    return data.cast<Map<String, dynamic>>();
  }
}
