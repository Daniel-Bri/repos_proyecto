import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:taller_movil/services/offline_queue_service.dart';

/// Excepción especial para token expirado — las páginas la atrapan y redirigen al login.
class TokenExpiradoException implements Exception {}

/// Excepción cuando no hay red (SocketException / ClientException / Timeout).
class SinConexionException implements Exception {
  @override
  String toString() => 'Sin conexión a internet. Verifica tu red e intenta de nuevo.';
}

/// Lanza [TokenExpiradoException] si la respuesta es 401/403, o [Exception] con el mensaje del backend.
void verificarRespuesta(http.Response res, {int esperado = 200}) {
  if (res.statusCode == esperado) return;
  if (res.statusCode == 401 || res.statusCode == 403) throw TokenExpiradoException();
  Object? detail;
  try {
    final body = jsonDecode(res.body);
    if (body is Map<String, dynamic>) {
      detail = body['detail'] ?? body['message'] ?? body['msg'];
    } else if (body is String) {
      detail = body;
    }
  } catch (_) {}
  throw Exception(detail?.toString() ?? 'Error ${res.statusCode}');
}

Never _handleNetworkError(Object e) {
  if (e is SocketException || e is http.ClientException || e is TimeoutException) {
    OfflineQueueService().marcarOffline();
    throw SinConexionException();
  }
  throw e;
}

Future<http.Response> safeGet(Uri url, {Map<String, String>? headers}) async {
  try {
    return await http.get(url, headers: headers).timeout(const Duration(seconds: 15));
  } catch (e) { _handleNetworkError(e); }
}

Future<http.Response> safePost(Uri url, {Map<String, String>? headers, Object? body}) async {
  try {
    return await http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 15));
  } catch (e) { _handleNetworkError(e); }
}

Future<http.Response> safePatch(Uri url, {Map<String, String>? headers, Object? body}) async {
  try {
    return await http.patch(url, headers: headers, body: body).timeout(const Duration(seconds: 15));
  } catch (e) { _handleNetworkError(e); }
}

Future<http.Response> safePut(Uri url, {Map<String, String>? headers, Object? body}) async {
  try {
    return await http.put(url, headers: headers, body: body).timeout(const Duration(seconds: 15));
  } catch (e) { _handleNetworkError(e); }
}

Future<http.Response> safeDelete(Uri url, {Map<String, String>? headers, Object? body}) async {
  try {
    return await http.delete(url, headers: headers, body: body).timeout(const Duration(seconds: 15));
  } catch (e) { _handleNetworkError(e); }
}

Future<http.StreamedResponse> safeSend(http.BaseRequest request) async {
  try {
    return await request.send().timeout(const Duration(seconds: 30));
  } catch (e) { _handleNetworkError(e); }
}
