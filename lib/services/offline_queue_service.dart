import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taller_movil/core/config/app_config.dart';
import 'auth_service.dart';

class OfflineAction {
  final String id;
  final String timestamp;
  final String endpoint;
  final String method;
  final Map<String, dynamic> body;
  final String label;

  OfflineAction({
    required this.id,
    required this.timestamp,
    required this.endpoint,
    required this.method,
    required this.body,
    required this.label,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'timestamp': timestamp, 'endpoint': endpoint,
    'method': method, 'body': body, 'label': label,
  };

  factory OfflineAction.fromJson(Map<String, dynamic> j) => OfflineAction(
    id: j['id'] as String,
    timestamp: j['timestamp'] as String,
    endpoint: j['endpoint'] as String,
    method: j['method'] as String,
    body: j['body'] as Map<String, dynamic>,
    label: j['label'] as String,
  );
}

class SyncResult {
  final int sincronizados;
  final List<String> labels;
  const SyncResult({required this.sincronizados, required this.labels});
}

class OfflineQueueService extends ChangeNotifier {
  static final OfflineQueueService _instance = OfflineQueueService._();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._();

  static const _key = 'rutasegura_offline_queue';
  // Backoff: 5s → 10s → 20s → 40s → 60s (se repite en 60s)
  static const _retryDelays = [5, 10, 20, 40, 60];

  final _auth = AuthService();
  List<OfflineAction> _queue = [];
  bool _sincronizando = false;
  bool _isOnline = true;
  int _retryCount = 0;
  Timer? _retryTimer;

  final _sincronizadoCtrl = StreamController<SyncResult>.broadcast();
  Stream<SyncResult> get sincronizadoStream => _sincronizadoCtrl.stream;

  int get pendientes => _queue.length;
  bool get isOnline => _isOnline;
  bool get isSincronizando => _sincronizando;
  List<OfflineAction> get queue => List.unmodifiable(_queue);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _queue = list.map((e) => OfflineAction.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        _queue = [];
      }
    }
    notifyListeners();
  }

  Future<void> encolar(String endpoint, String method, Map<String, dynamic> body, String label) async {
    _queue.add(OfflineAction(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      timestamp: DateTime.now().toIso8601String(),
      endpoint: endpoint,
      method: method,
      body: body,
      label: label,
    ));
    await _guardar();
    notifyListeners();
    debugPrint('[OfflineQueue] Encolado: $label (total: ${_queue.length})');
  }

  /// Llamado desde servicios HTTP cuando se detecta un SocketException
  void marcarOffline() {
    if (_isOnline) {
      _isOnline = false;
      notifyListeners();
      _programarRetry();
    }
  }

  Future<bool> probarConectividad() async {
    try {
      final res = await http
          .head(Uri.parse('${AppConfig.baseUrl}/'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  Future<void> probarYSincronizar() async {
    final alcanzable = await probarConectividad();
    if (_isOnline != alcanzable) {
      _isOnline = alcanzable;
      notifyListeners();
    }
    if (alcanzable) {
      _retryCount = 0;
      await sincronizar();
    } else {
      _programarRetry();
    }
  }

  Future<void> sincronizar() async {
    if (_sincronizando || _queue.isEmpty || !_isOnline) return;
    _sincronizando = true;
    notifyListeners();

    final token = await _auth.getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final pendientes = [..._queue];
    final labels = <String>[];
    int sincronizados = 0;
    bool falloRed = false;

    for (final action in pendientes) {
      try {
        final url = Uri.parse('${AppConfig.baseUrl}${action.endpoint}');
        http.Response res;
        if (action.method == 'POST') {
          res = await http.post(url, headers: headers, body: jsonEncode(action.body))
              .timeout(const Duration(seconds: 10));
        } else if (action.method == 'PATCH') {
          res = await http.patch(url, headers: headers, body: jsonEncode(action.body))
              .timeout(const Duration(seconds: 10));
        } else {
          res = await http.put(url, headers: headers, body: jsonEncode(action.body))
              .timeout(const Duration(seconds: 10));
        }

        if (res.statusCode >= 200 && res.statusCode < 400) {
          labels.add(action.label);
          sincronizados++;
          _queue.removeWhere((a) => a.id == action.id);
          await _guardar();
          notifyListeners();
          debugPrint('[OfflineQueue] Sincronizado: ${action.label}');
        } else if (res.statusCode >= 400 && res.statusCode < 500) {
          // Error del cliente — acción inválida, descartar y continuar
          _queue.removeWhere((a) => a.id == action.id);
          await _guardar();
          notifyListeners();
        } else {
          // Error servidor (5xx) — parar y reintentar con backoff
          falloRed = true;
          break;
        }
      } catch (e) {
        // SocketException / timeout — sin red
        debugPrint('[OfflineQueue] Error de red: $e');
        falloRed = true;
        break;
      }
    }

    _sincronizando = false;
    notifyListeners();

    if (sincronizados > 0) {
      _sincronizadoCtrl.add(SyncResult(sincronizados: sincronizados, labels: labels));
    }

    if (falloRed) {
      _isOnline = false;
      notifyListeners();
      _programarRetry();
    }
  }

  void _programarRetry() {
    if (_queue.isEmpty) return;
    _retryTimer?.cancel();
    final delaySecs = _retryDelays[_retryCount.clamp(0, _retryDelays.length - 1)];
    _retryCount++;
    debugPrint('[OfflineQueue] Próximo reintento en ${delaySecs}s (intento #$_retryCount)');
    _retryTimer = Timer(Duration(seconds: delaySecs), () => probarYSincronizar());
  }

  void limpiar() async {
    _queue.clear();
    _retryTimer?.cancel();
    await _guardar();
    notifyListeners();
  }

  Future<void> _guardar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_queue.map((a) => a.toJson()).toList()));
  }
}
